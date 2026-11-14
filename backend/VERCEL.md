# NEXORA AI — Vercel backend setup

I prepared a Vercel serverless endpoint at `api/chat.js`. It keeps the Gemini key on the server instead of inside the iPhone app.

## One-time setup

1. Open https://vercel.com/signup and continue with GitHub.
2. Import the repository `wozymiyim-debug/WOZY-NOVA`.
3. In the project settings, add an Environment Variable:
   - Name: `GEMINI_API_KEY`
   - Value: your Gemini API key
   - Environment: Production
4. Deploy the project. The API endpoint will be:
   `https://YOUR-VERCEL-DOMAIN.vercel.app/api/chat`
5. Copy that deployed URL into `NexoraClient.endpoint` in `ChatView.swift` (include `/api/chat`), commit, and rebuild the iOS app.

Do not commit the Gemini key to GitHub or put it in the iOS app.

## Free-tier note

Vercel Hobby is free for personal, non-commercial projects and has usage limits. Gemini API usage is separate and may incur charges or limits. A server hides the key from app users; it does not make AI inference itself free.

Official details:
- https://vercel.com/pricing
- https://vercel.com/docs/plans/hobby
- https://vercel.com/docs/environment-variables
