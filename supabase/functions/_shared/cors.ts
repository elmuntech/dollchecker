// Shared CORS headers for browser/Flutter-web callers. Native mobile does not
// require CORS, but keeping this here lets the same function serve Flutter web.
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
