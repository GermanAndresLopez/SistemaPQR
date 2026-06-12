const nodemailer = require("nodemailer");

let transport;

function obtenerTransporte() {
  if (!transport) {
    transport = nodemailer.createTransport({
      host: process.env.EMAIL_HOST,
      port: parseInt(process.env.EMAIL_PORT, 10) || 587,
      secure: process.env.EMAIL_SECURE === "true",
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
  }
  return transport;
}

// Lambda invocada de forma asíncrona ("Event") por el backend para enviar
// correos sin bloquear la respuesta HTTP. Recibe { to, subject, html }.
exports.handler = async (event) => {
  const { to, subject, html } = event || {};

  if (!to || !subject || !html) {
    throw new Error("Faltan campos requeridos: to, subject, html");
  }

  const info = await obtenerTransporte().sendMail({
    from: process.env.EMAIL_FROM,
    to,
    subject,
    html,
  });

  return { ok: true, messageId: info.messageId };
};
