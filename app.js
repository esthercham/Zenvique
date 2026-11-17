// Shared code for every Zenvique page.
// Load order on each page: supabase-js CDN → config.js → app.js → page script.

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

const App = {
  sb,

  // The logged-in person's profile, or null if not logged in.
  async getProfile() {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) return null;
    const { data, error } = await sb
      .from('profiles')
      .select('id, email, full_name, role, outlet, active')
      .eq('id', session.user.id)
      .maybeSingle();
    if (error) throw error;
    return data;
  },

  // Put at the top of every page: sends people who aren't allowed back to index.html.
  // (The real protection is Row Level Security in the database.)
  async requireRole(allowedRoles) {
    let profile = null;
    try { profile = await App.getProfile(); } catch (e) { /* treat as not allowed */ }
    if (!profile || !profile.active || (allowedRoles && !allowedRoles.includes(profile.role))) {
      window.location.href = 'index.html';
      return new Promise(() => {}); // stop the page while redirecting
    }
    return profile;
  },

  async logout() {
    await sb.auth.signOut();
    window.location.href = 'index.html';
  },

  // Money: RM 1,234.50
  rm(n) {
    const v = Number(n || 0);
    return 'RM ' + v.toLocaleString('en-MY', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  },

  // Dates: 17 Nov 2026
  date(d) {
    if (!d) return '';
    const dt = typeof d === 'string' && d.length === 10 ? new Date(d + 'T00:00:00') : new Date(d);
    return dt.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  },

  roleLabel(role) {
    return { owner: 'Owner', manager: 'Manager', staff: 'Staff' }[role] || 'Staff';
  },

  // Safe text for putting into HTML
  esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  },

  // Turn technical errors into friendly messages
  friendlyError(err) {
    const msg = (err && (err.message || err.error_description || String(err))) || '';
    const m = msg.toLowerCase();
    if (m.includes('invalid login credentials')) return 'Email or password is wrong. Please try again.';
    if (m.includes('email not confirmed')) return 'Please confirm your email first. Check your inbox for the link.';
    if (m.includes('already registered') || m.includes('already been registered'))
      return 'This email already has an account. Please log in instead.';
    if (m.includes('password') && (m.includes('at least') || m.includes('short')))
      return 'Password must be at least 6 characters.';
    if (m.includes('valid email') || m.includes('invalid email')) return 'Please enter a valid email address.';
    if (m.includes('rate limit') || m.includes('too many')) return 'Too many tries. Please wait a few minutes and try again.';
    if (m.includes('failed to fetch') || m.includes('network')) return "Can't reach the server. Check your internet and try again.";
    if (m.includes('row-level security') || m.includes('permission denied'))
      return "You don't have permission to do this.";
    // Our own database messages are already friendly
    if (msg && msg.length < 160 && !m.includes('violates') && !m.includes('syntax')) return msg;
    return 'Something went wrong. Please try again.';
  },

  // Fetch ALL rows (Supabase sends max 1,000 per request). build = () => a fresh query.
  async fetchAll(build) {
    const size = 1000;
    let from = 0, out = [];
    for (;;) {
      const { data, error } = await build().range(from, from + size - 1);
      if (error) throw error;
      out = out.concat(data || []);
      if (!data || data.length < size) return out;
      from += size;
    }
  },

  // ---- Dates & months ----
  todayKL() { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kuala_Lumpur' }).format(new Date()); },
  ym(d) { return String(d).slice(0, 7); },
  monthEnd(m) { const [y, mo] = m.split('-').map(Number); return new Date(Date.UTC(y, mo, 0)).toISOString().slice(0, 10); },
  addMonths(m, n) { const [y, mo] = m.split('-').map(Number); return new Date(Date.UTC(y, mo - 1 + n, 1)).toISOString().slice(0, 7); },
  monthLabel(m) { return new Date(m + '-01T00:00:00').toLocaleDateString('en-GB', { month: 'short', year: 'numeric' }); },
  dateTime(d) {
    return new Date(d).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Asia/Kuala_Lumpur' });
  },

  // A sale's paid total split into treatment / product (after discount)
  shares(s) {
    const gross = Number(s.treatment_amount) + Number(s.product_amount);
    const f = gross > 0 ? Number(s.total_sale) / gross : 0;
    return { trt: Number(s.treatment_amount) * f, prod: Number(s.product_amount) * f };
  },
  custKey(s) { return (s.phone || '').replace(/\D/g, '') || (s.customer_name || '').trim().toLowerCase(); },

  // Owner admin tabs (shown at the top of owner pages)
  ownerTabs(active) {
    const tabs = [['owner.html', 'Overview'], ['users.html', 'Users'], ['settings.html', 'Settings'],
                  ['history.html', 'History'], ['export.html', 'Download'], ['dashboard.html', 'Manager view']];
    return `<nav class="tabbar">${tabs.map(([href, label]) =>
      `<a href="${href}" class="${href === active ? 'active' : ''}">${label}</a>`).join('')}</nav>`;
  },

  // Show a message in a box: type = 'error' | 'ok' | 'info'
  showMsg(el, text, type = 'info') {
    if (!el) return;
    el.textContent = text || '';
    el.className = 'msg ' + (text ? type : '');
  },
};
