import 'dart:html' as html;

/// Web-only: exports a 1080×1350 PNG poster with a member referral URL.
Future<bool> downloadGenesisPoster(String inviteUrl) async {
  final canvas = html.CanvasElement(width: 1080, height: 1350);
  final ctx = canvas.context2D;
  final bg = ctx.createLinearGradient(0, 0, 1080, 1350);
  bg.addColorStop(0, '#050B17');
  bg.addColorStop(0.52, '#132943');
  bg.addColorStop(1, '#060C17');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, 1080, 1350);
  ctx.strokeStyle = '#C8A867';
  ctx.lineWidth = 3;
  ctx.strokeRect(55, 55, 970, 1240);
  ctx.textAlign = 'center';
  ctx.fillStyle = '#E3C78C';
  ctx.font = 'bold 42px Georgia';
  ctx.fillText('✦ THE GENESIS ERA ✦', 540, 200);
  ctx.font = 'bold 116px Georgia';
  ctx.fillText('GENESIS', 540, 510);
  ctx.font = '46px Georgia';
  ctx.fillText('JOIN THE NEW ERA', 540, 590);
  ctx.strokeStyle = '#C8A867';
  ctx.beginPath();
  ctx.moveTo(240, 660);
  ctx.lineTo(840, 660);
  ctx.stroke();
  ctx.fillStyle = '#F5E9D3';
  ctx.font = '36px Georgia';
  ctx.fillText('WE ARE NOT WAITING FOR GOD.', 540, 760);
  ctx.fillText('WE ARE WAITING FOR AN ANSWER.', 540, 815);
  ctx.fillStyle = '#E3C78C';
  ctx.font = 'bold 37px sans-serif';
  ctx.fillText('DOŁĄCZ DO SPOŁECZNOŚCI', 540, 975);
  ctx.fillStyle = '#FFFFFF';
  ctx.font = '26px sans-serif';
  // Split long URLs into two lines to keep the poster legible.
  final midpoint = (inviteUrl.length / 2).ceil();
  final split = inviteUrl.lastIndexOf('/', midpoint);
  if (inviteUrl.length > 60 && split > 12) {
    ctx.fillText(inviteUrl.substring(0, split + 1), 540, 1070);
    ctx.fillText(inviteUrl.substring(split + 1), 540, 1115);
  } else {
    ctx.fillText(inviteUrl, 540, 1090);
  }
  ctx.fillStyle = '#E3C78C';
  ctx.font = '23px sans-serif';
  ctx.fillText('TWÓJ OSOBISTY LINK ZAPROSZENIA', 540, 1200);
  final anchor = html.AnchorElement(href: canvas.toDataUrl('image/png'))
    ..download = 'the-genesis-era-zaproszenie.png';
  anchor.click();
  return true;
}
