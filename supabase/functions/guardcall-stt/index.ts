// Supabase Edge Function: guardcall-stt
//
// Secure Speech-to-Text backend proxy for GuardCall.
// Protects provider API secrets (Whisper / Speech-to-Text) inside Supabase Edge Function
// environment secrets so mobile APK clients never hold sensitive credentials.
//
// Enforces:
// 1. Mandatory user authentication via Supabase JWT (HTTP 401 on failure).
// 2. Strict input validation and audio file size limits (HTTP 400 on failure).
// 3. Strict response validation before returning conversation lines to Flutter.
// 4. Zero database persistence: audio data is discarded immediately after processing.
//    Never written to Supabase Storage or PostgreSQL tables.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_AUDIO_BYTES = 10 * 1024 * 1024; // 10MB limit

serve(async (req: Request) => {
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

    if (!body || typeof body !== "object") {
      return new Response(
        JSON.stringify({ error: "Request body must be a valid JSON object." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const audioBase64 = String(body.audio_base64 || "").trim();
    if (!audioBase64) {
      return new Response(
        JSON.stringify({ error: "Audio data ('audio_base64') is required and cannot be empty." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Base64 size estimation
    const estimatedBytes = (audioBase64.length * 3) / 4;
    if (estimatedBytes > MAX_AUDIO_BYTES) {
      return new Response(
        JSON.stringify({ error: `Audio payload exceeds maximum limit of 10MB (${Math.round(estimatedBytes / 1024)} KB).` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------
    // PHASE E — PROVIDER SECRET MANAGEMENT
    // -------------------------------------------------------------
    const apiKey = (
      Deno.env.get("SPEECH_TO_TEXT_API_KEY") ||
      Deno.env.get("OPENAI_API_KEY") ||
      ""
    ).trim();

    if (!apiKey || apiKey.includes("your-") || apiKey.includes("placeholder")) {
      return new Response(
        JSON.stringify({ error: "Speech-to-text provider credentials are not configured on this server." }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // -------------------------------------------------------------
    // PHASE G — CALL STT PROVIDER & VALIDATE RESPONSE
    // -------------------------------------------------------------
    // Decode base64 to binary and prepare multipart upload to Whisper
    let binaryAudio: Uint8Array;
    try {
      const binaryString = atob(audioBase64);
      binaryAudio = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        binaryAudio[i] = binaryString.charCodeAt(i);
      }
    } catch {
      return new Response(
        JSON.stringify({ error: "Failed to decode base64 audio data." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const formData = new FormData();
    const audioBlob = new Blob([binaryAudio], { type: body.content_type || "audio/wav" });
    formData.append("file", audioBlob, "audio.wav");
    formData.append("model", "whisper-1");

    const whisperRes = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
      body: formData,
    });

    if (!whisperRes.ok) {
      return new Response(
        JSON.stringify({ error: `Upstream STT provider error: HTTP ${whisperRes.status}` }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const whisperData = await whisperRes.json();
    const rawText = String(whisperData?.text || "").trim();

    // Segment text into structured conversation lines
    const sentences = rawText
      .split(/(?<=[.?!])\s+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    const lines = sentences.map((text) => ({
      speaker: "caller",
      text,
    }));

    // Return structured dialogue turns without persisting raw audio anywhere
    return new Response(JSON.stringify({ lines }), {
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
