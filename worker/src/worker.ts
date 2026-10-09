// Cloudflare Worker: Orator Neural TTS Proxy (Rule 11 Compliant)
// Provides studio-quality human voice streaming powered by Gemini 3.8 Flash TTS
// Default voice: Aoede (melodic, warm, articulate executive orator female voice)
// Alternate voice: Puck (upbeat, clear executive orator male voice)

export interface Env {
  GEMINI_API_KEY: string;
  DEFAULT_VOICE?: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // 1. CORS Preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    // 2. Health Check
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          service: "Orator Neural TTS Edge Proxy",
          version: "1.0.0",
          supportedVoices: ["Aoede", "Kore", "Puck", "Charon"],
          timestamp: new Date().toISOString(),
        }),
        {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // 3. TTS Endpoint (/api/tts)
    if (url.pathname === "/api/tts") {
      let text = "";
      let voice = env.DEFAULT_VOICE || "Aoede";

      if (request.method === "GET") {
        text = url.searchParams.get("text") || "";
        voice = url.searchParams.get("voice") || voice;
      } else if (request.method === "POST") {
        try {
          const body: any = await request.json();
          text = body.text || "";
          voice = body.voice || voice;
        } catch {
          return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
            status: 400,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          });
        }
      } else {
        return new Response("Method not allowed", { status: 405 });
      }

      text = text.trim();
      if (!text) {
        return new Response(JSON.stringify({ error: "Missing 'text' parameter" }), {
          status: 400,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }

      const apiKey = env.GEMINI_API_KEY;
      if (!apiKey) {
        return new Response(JSON.stringify({ error: "Server missing GEMINI_API_KEY secret" }), {
          status: 500,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }

      try {
        const models = ["gemini-3.8-flash-lite-tts", "gemini-3.8-flash-tts"];
        let geminiResp: Response | null = null;
        let lastErrorText = "";

        for (const model of models) {
          const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/interactions?key=${encodeURIComponent(apiKey)}`;
          const geminiPayload = {
            model: model,
            input: [
              {
                type: "user_input",
                content: [
                  {
                    type: "text",
                    text: text,
                    annotations: [
                      {
                        type: "speech_metadata",
                        style: "articulate, warm, clear executive orator pronunciation",
                      },
                    ],
                  },
                ],
              },
            ],
            response_format: {
              type: "audio",
            },
            generation_config: {
              speech_config: [
                {
                  voice: voice,
                },
              ],
            },
          };

          const resp = await fetch(geminiUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(geminiPayload),
          });

          if (resp.ok) {
            geminiResp = resp;
            break;
          } else {
            lastErrorText = await resp.text();
            // Continue to next model if 429 rate-limited or 503
            if (resp.status !== 429 && resp.status !== 503) {
              break;
            }
          }
        }

        if (!geminiResp) {
          return new Response(JSON.stringify({ error: "Upstream Gemini error", details: lastErrorText }), {
            status: 502,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          });
        }

        const data: any = await geminiResp.json();
        let base64Audio = "";

        if (data.output_audio && data.output_audio.data) {
          base64Audio = data.output_audio.data;
        } else if (data.steps && Array.isArray(data.steps)) {
          for (const step of data.steps) {
            if (step.type === "model_output" && Array.isArray(step.content)) {
              for (const part of step.content) {
                if (part.type === "audio" && part.data) {
                  base64Audio = part.data;
                  break;
                }
              }
            }
            if (base64Audio) break;
          }
        }

        if (!base64Audio) {
          return new Response(JSON.stringify({ error: "No audio generated in model output" }), {
            status: 502,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          });
        }

        // Convert base64 to binary ArrayBuffer
        const binaryString = atob(base64Audio);
        const len = binaryString.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }

        return new Response(bytes.buffer, {
          status: 200,
          headers: {
            "Content-Type": "audio/wav",
            "Content-Length": len.toString(),
            "Cache-Control": "public, max-age=604800, immutable", // Cache for 7 days at edge & client
            "Access-Control-Allow-Origin": "*",
            "X-Orator-Voice": voice,
          },
        });
      } catch (err: any) {
        return new Response(JSON.stringify({ error: "Internal server error", message: err.message }), {
          status: 500,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
    }

    return new Response("Not found", { status: 404 });
  },
};
