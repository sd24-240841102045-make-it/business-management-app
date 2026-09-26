import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import nodemailer from "npm:nodemailer@6.9.10";

// Retrieve Gmail credentials from Supabase secrets
const GMAIL_USER = Deno.env.get("GMAIL_USER");
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { to, code, role, organization_name, subject, body } = await req.json();

    if (!to || !code) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: 'to' or 'code'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!GMAIL_USER || !GMAIL_APP_PASSWORD) {
      return new Response(
        JSON.stringify({
          error: "Gmail credentials not configured in Supabase. Please set GMAIL_USER and GMAIL_APP_PASSWORD secrets.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Configure Nodemailer with Gmail SMTP
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: GMAIL_USER,
        pass: GMAIL_APP_PASSWORD.replace(/\s+/g, ""), // strip any spaces from Google App Password
      },
    });

    const orgName = organization_name || "Business Management Suite";
    const roleTitle = role === "client" ? "Client Lead" : "Staff Employee";

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; margin: 0; padding: 24px; color: #ffffff; }
          .card { max-width: 580px; margin: 0 auto; background: #131926; border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 32px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
          .header { text-align: center; margin-bottom: 24px; }
          .logo { font-size: 24px; font-weight: 800; color: #d4af37; letter-spacing: 1px; }
          .title { font-size: 20px; font-weight: 700; color: #ffffff; margin-top: 8px; }
          .subtitle { font-size: 14px; color: #94a3b8; }
          .code-box { background: rgba(212, 175, 55, 0.12); border: 1.5px solid #d4af37; border-radius: 12px; padding: 20px; text-align: center; margin: 28px 0; }
          .code-label { font-size: 11px; font-weight: 700; color: #d4af37; letter-spacing: 2px; text-transform: uppercase; margin-bottom: 6px; }
          .code { font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #d4af37; font-family: monospace; }
          .steps { background: rgba(255,255,255,0.03); border-radius: 12px; padding: 20px; margin: 24px 0; }
          .step-item { margin-bottom: 12px; font-size: 14px; color: #cbd5e1; line-height: 1.5; }
          .step-num { color: #d4af37; font-weight: bold; margin-right: 6px; }
          .footer { font-size: 12px; color: #64748b; text-align: center; margin-top: 28px; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <div class="logo">⚡ ${orgName}</div>
            <div class="title">You're Invited to Join</div>
            <div class="subtitle">Access invitation for ${roleTitle} account</div>
          </div>

          <p style="color: #cbd5e1; font-size: 14px; line-height: 1.6;">
            Hello,<br><br>
            You have been invited to join <strong>${orgName}</strong> on the Business Management Suite as a <strong>${roleTitle}</strong>.
          </p>

          <div class="code-box">
            <div class="code-label">Your Access Invitation Code</div>
            <div class="code">${code}</div>
          </div>

          <div class="steps">
            <div style="font-weight: bold; color: #ffffff; margin-bottom: 12px; font-size: 14px;">How to Log In & Activate Account:</div>
            <div class="step-item"><span class="step-num">1.</span> Open the Business Management application.</div>
            <div class="step-item"><span class="step-num">2.</span> On the Login screen, click <strong>"Join with Code"</strong>.</div>
            <div class="step-item"><span class="step-num">3.</span> Enter your Invitation Code: <strong>${code}</strong></div>
            <div class="step-item"><span class="step-num">4.</span> Enter your email: <strong>${to}</strong></div>
            <div class="step-item"><span class="step-num">5.</span> Create your password and click <strong>"Login with Invitation Code"</strong>.</div>
          </div>

          <p style="color: #94a3b8; font-size: 13px;">
            ⚠️ This code is unique to your email address and will expire in 7 days.
          </p>

          <div class="footer">
            Sent by ${orgName} via Business Management Suite.<br>
            If you did not expect this invitation, please ignore this email.
          </div>
        </div>
      </body>
      </html>
    `;

    // Send email via Gmail
    const mailOptions = {
      from: `"${orgName}" <${GMAIL_USER}>`,
      to,
      subject: subject || `Invitation to join ${orgName} on Business Suite`,
      text: body || `Your invitation code to join ${orgName} is: ${code}`,
      html: htmlContent,
    };

    const info = await transporter.sendMail(mailOptions);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Email sent successfully via Gmail!",
        messageId: info.messageId,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || "Failed to send email via Gmail" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
