// Public OG previews are available ONLY for posts in public groups.
// No user-provided HTML is rendered; text is escaped.
const project = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const app = "https://aiglobalcommunity.github.io/ai-global-app/";
const escapeHtml = (s: string) => s.replace(/[&<>"']/g, c =>
  ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c] || c));
Deno.serve(async (request: Request) => {
  const url = new URL(request.url);
  const id = url.searchParams.get("id") || "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))
    return new Response("Invalid post", {status:400});
  const api = new URL(project + "/rest/v1/agc_group_posts");
  api.searchParams.set("select","id,body,author_label,image_path,video_url,agc_groups!inner(visibility)");
  api.searchParams.set("id","eq."+id);
  api.searchParams.set("agc_groups.visibility","eq.public");
  api.searchParams.set("limit","1");
  const response = await fetch(api, {headers:{
    apikey:serviceKey,Authorization:"Bearer "+serviceKey
  }});
  if (!response.ok) return new Response("Unavailable", {status:503});
  const posts = await response.json();
  if (!Array.isArray(posts) || posts.length === 0)
    return new Response("Post unavailable", {status:404});
  const post = posts[0];
  const destination = app+"?post="+encodeURIComponent(id);
  const title = escapeHtml("THE GENESIS ERA · "+String(post.author_label||"Community").slice(0,100));
  const description = escapeHtml(String(post.body||"").replace(/\s+/g," ").slice(0,240));
  let image = app+"icons/Icon-512.png";
  if (typeof post.image_path === "string" &&
      /^[0-9a-f-]{36}\/[0-9]+_[0-9]+\.(jpg|jpeg|png|webp|gif)$/.test(post.image_path)) {
    image = project+"/storage/v1/object/public/agc-forum-images/"+post.image_path;
  } else if (typeof post.video_url === "string") {
    try {
      const v = new URL(post.video_url);
      const host = v.hostname.toLowerCase();
      const candidate = host==="youtu.be" ? v.pathname.slice(1) :
        ["youtube.com","www.youtube.com","m.youtube.com"].includes(host) ?
        v.searchParams.get("v") : null;
      if (candidate && /^[\w-]{11}$/.test(candidate))
        image="https://img.youtube.com/vi/"+candidate+"/hqdefault.jpg";
    } catch { /* no thumbnail */ }
  }
  const canonical = escapeHtml(url.origin+url.pathname+"?id="+id);
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta property="og:type" content="article"><meta property="og:site_name" content="THE GENESIS ERA">
<meta property="og:title" content="${title}"><meta property="og:description" content="${description}">
<meta property="og:image" content="${escapeHtml(image)}">
<meta property="og:url" content="${canonical}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
<meta name="twitter:image" content="${escapeHtml(image)}">
<meta http-equiv="refresh" content="0;url=${destination}">
<title>${title}</title></head><body>
<a href="${destination}">Open post in THE GENESIS ERA</a></body></html>`;
  return new Response(html, {headers:{
    "Content-Type":"text/html; charset=utf-8",
    "Cache-Control":"public, max-age=60",
    "X-Content-Type-Options":"nosniff",
    "Content-Security-Policy":"default-src 'none'; img-src https:; style-src 'none'"
  }});
});