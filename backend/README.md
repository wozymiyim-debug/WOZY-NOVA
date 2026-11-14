# NEXORA AI backend

The iOS app now sends chat requests to a server endpoint. The Gemini API key is **not** stored in the app.

## Deploy on Cloudflare Workers

1. Sign in to Cloudflare and open **Workers & Pages**.
2. Create a Worker named `nexora-ai-api`.
3. Open its editor and replace the starter code with `backend/worker.js` from this repository.
4. In the Worker settings, open **Variables and Secrets** and add a secret:
   - Name: `GEMINI_API_KEY`
   - Value: your Gemini API key
5. Deploy the Worker. Its address will look like `https://nexora-ai-api.<your-account>.workers.dev`.

Do not put the Gemini key in the iOS app, GitHub source files, or a public message.

## Connect the iOS app

In `ChatView.swift`, replace the placeholder in `NexoraClient.endpoint` with:

`https://nexora-ai-api.<your-account>.workers.dev/chat`

Then commit the change and let the iOS build workflow run.

## Important

The API key is entered once as a server-side secret, not every time the app opens. Gemini may still charge or enforce usage limits for requests. Before sharing the app publicly, configure rate limiting and usage monitoring for the Worker so others cannot consume your API quota.
