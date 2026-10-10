// Supabase Edge Function: guardcall-ai-analyze
//
// Secure AI backend proxy for GuardCall scam conversation analysis.
// Protects provider API secrets (OpenAI / Gemini) inside Supabase Edge Function
// environment secrets so mobile APK clients never hold sensitive credentials.
//
// Enforces:
// 1. Mandatory user authentication via Supabase JWT (HTTP 401 on failure).
// 2. Strict input validation and payload bounds (HTTP 400 on failure).
// 3. Strict schema validation of AI responses before returning to Flutter.
// 4. Zero database persistence of call transcripts or conversation text.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const VALID_SIGNAL_TYPES = new Set([
  "urgency",
  "fear_threat",
  "authority_impersonation",
  "sensitive_information_request",
  "financial_pressure",
  "isolation",
  "emotional_manipulation",
  "remote_access_request",
  "suspicious_link",
]);

const VALID_SEVERITIES = new Set(["low", "medium", "high", "critical"]);

serve(async (req: Request) => {
  // Handle CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // -------------------------------------------------------------
    // PHASE C — AUTHENTICATION
    // -------------------------------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing or invalid Bearer authentication token." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    if (!supabaseUrl || !supabaseAnonKey) {
      return new Response(
        JSON.stringify({ error: "Backend service configuration error." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid or expired Supabase authentication session." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------
    // PHASE D — INPUT VALIDATION
    // -------------------------------------------------------------
    let body: any;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!body || !Array.isArray(body.conversation)) {
      return new Response(
        JSON.stringify({ error: "Request body must include a 'conversation' array." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const conversation = body.conversation;
    if (conversation.length === 0) {
      return new Response(
        JSON.stringify({ error: "Conversation must contain at least one dialogue line." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (conversation.length > 100) {
      return new Response(
        JSON.stringify({ error: "Conversation exceeds maximum allowable length of 100 dialogue turns." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let totalChars = 0;
    for (let i = 0; i < conversation.length; i++) {
      const line = conversation[i];
      if (!line || typeof line !== "object") {
        return new Response(
          JSON.stringify({ error: `Conversation line ${i} is not a valid object.` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const speaker = String(line.speaker || "").toLowerCase();
      if (speaker !== "caller" && speaker !== "user" && speaker !== "callee") {
        return new Response(
          JSON.stringify({ error: `Conversation line ${i} has invalid speaker: '${line.speaker}'.` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const text = String(line.text || "").trim();
      if (!text) {
        return new Response(
          JSON.stringify({ error: `Conversation line ${i} contains empty text.` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (text.length > 2000) {
        return new Response(
          JSON.stringify({ error: `Conversation line ${i} exceeds maximum length of 2000 characters.` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      totalChars += text.length;
    }

    if (totalChars > 50000) {
      return new Response(
        JSON.stringify({ error: "Total conversation text exceeds maximum 50,000 character limit." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------
    // PHASE E — PROVIDER SECRET MANAGEMENT
    // -------------------------------------------------------------
    const provider = (Deno.env.get("AI_PROVIDER") || "openai").toLowerCase().trim();
    let apiKey = "";

    if (provider === "gemini") {
      apiKey = (Deno.env.get("GEMINI_API_KEY") || "").trim();
    } else {
      apiKey = (Deno.env.get("OPENAI_API_KEY") || "").trim();
    }

    if (!apiKey || apiKey.includes("your-") || apiKey.includes("placeholder")) {
      return new Response(
        JSON.stringify({ error: "AI provider credentials are not configured on this server." }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------
    // PHASE F — AI ANALYSIS DISPATCH & STRICT SCHEMA VALIDATION
    // -------------------------------------------------------------
    const dialogueText = conversation
      .map((l: any) => `${l.speaker.toUpperCase()}: ${l.text}`)
      .join("\n");

    const prompt = `You are GuardCall, an AI protecting seniors from phone scams. Analyze this phone conversation transcript for manipulation:\n\n${dialogueText}\n\nRespond STRICTLY with this JSON structure without markdown formatting:
{
  "risk_score": 0-100,
  "confidence": 0.0-1.0,
  "signals": [
    {
      "type": "urgency" | "fear_threat" | "authority_impersonation" | "sensitive_information_request" | "financial_pressure" | "isolation" | "emotional_manipulation" | "remote_access_request" | "suspicious_link",
      "severity": "low" | "medium" | "high" | "critical",
      "explanation": "concise plain text rationale"
    }
  ],
  "summary": "plain English explanation for an elderly person"
}`;

    let rawAiText = "";

    if (provider === "gemini") {
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
      const geminiRes = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: "application/json",
          },
        }),
      });

      if (!geminiRes.ok) {
        return new Response(
          JSON.stringify({ error: `Upstream AI provider error: HTTP ${geminiRes.status}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const geminiData = await geminiRes.json();
      rawAiText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    } else {
      // Default: OpenAI
      const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content: "You are a phone scam detection system that outputs strictly structured JSON.",
            },
            { role: "user", content: prompt },
          ],
          temperature: 0.1,
          response_format: { type: "json_object" },
        }),
      });

      if (!openaiRes.ok) {
        return new Response(
          JSON.stringify({ error: `Upstream AI provider error: HTTP ${openaiRes.status}` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const openaiData = await openaiRes.json();
      rawAiText = openaiData?.choices?.[0]?.message?.content ?? "";
    }

    // Parse and validate AI output strictly
    let parsed: any;
    try {
      parsed = JSON.parse(rawAiText);
    } catch {
      return new Response(
        JSON.stringify({ error: "Upstream AI provider returned unparseable output." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. risk_score
    if (typeof parsed.risk_score !== "number" || parsed.risk_score < 0 || parsed.risk_score > 100) {
      return new Response(
        JSON.stringify({ error: "Invalid AI response: 'risk_score' must be a number between 0 and 100." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. confidence
    if (typeof parsed.confidence !== "number" || parsed.confidence < 0 || parsed.confidence > 1) {
      return new Response(
        JSON.stringify({ error: "Invalid AI response: 'confidence' must be a number between 0.0 and 1.0." }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. signals
    const signals = Array.isArray(parsed.signals) ? parsed.signals : [];
    const validatedSignals = [];
    for (const sig of signals) {
      if (!sig || typeof sig !== "object") continue;
      const type = String(sig.type || "").toLowerCase().trim();
      if (!VALID_SIGNAL_TYPES.has(type)) {
        return new Response(
          JSON.stringify({ error: `Invalid AI response: unknown signal type '${type}'.` }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      const severity = String(sig.severity || "medium").toLowerCase().trim();
      const explanation = String(sig.explanation || "").trim();
      if (!explanation) {
        return new Response(
          JSON.stringify({ error: "Invalid AI response: signal explanation cannot be empty." }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      validatedSignals.push({
        type,
        severity: VALID_SEVERITIES.has(severity) ? severity : "medium",
        explanation,
      });
    }

    const summary = typeof parsed.summary === "string" && parsed.summary.trim()
      ? parsed.summary.trim()
      : (parsed.risk_score < 40 ? "No significant scam indicators identified." : "Potential scam activity detected.");

    const result = {
      risk_score: Math.round(parsed.risk_score),
      confidence: parsed.confidence,
      signals: validatedSignals,
      summary,
    };

    // Return sanitized, strictly validated structured response
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: `Internal server error: ${err?.message || "Unexpected failure"}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
