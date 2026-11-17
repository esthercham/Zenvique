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
      .select('id, email, full_name, role, outlet, active, phone')
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

  // ---------------- Alerts (Red = Act now, Amber = Watch) ----------------
  async loadAlerts() {
    return App.fetchAll(() => sb.rpc('my_alerts'));
  },
  // record id -> 'red' | 'amber' (red wins)
  alertLevels(alerts) {
    const m = new Map();
    (alerts || []).forEach(a => { if (m.get(a.record_id) !== 'red') m.set(a.record_id, a.level); });
    return m;
  },
  rowClass(levels, id) { const l = levels && levels.get(String(id)); return l ? 'row-' + l : ''; },
  legendHtml() {
    return `<div class="legend"><span><i class="dot red"></i><strong>Red</strong> = Act now</span>
      <span><i class="dot amber"></i><strong>Amber</strong> = Watch</span></div>`;
  },
  // Malaysian numbers: 012-345 6789 -> 60123456789
  waNumber(phone) {
    let d = String(phone || '').replace(/\D/g, '');
    if (!d) return '';
    if (d.startsWith('0')) d = '6' + d;
    return d;
  },
  waLink(phone, text) {
    const n = App.waNumber(phone);
    return `https://wa.me/${n}?text=${encodeURIComponent(text)}`;
  },

  // Render the Alerts box. opts: { me, ownerWhatsapp, onChange }
  renderAlerts(el, alerts, opts) {
    const me = opts.me, onChange = opts.onChange || (() => {});
    const STAFF_FOLLOWUP = ['incomplete', 'missing_staff', 'missing_marketing', 'commission_error', 'high_discount'];
    const reds = alerts.filter(a => a.level === 'red').length, ambers = alerts.length - reds;
    if (!alerts.length) {
      el.innerHTML = `<div class="alertbox ok"><strong>Alerts</strong> · Nothing needs attention right now. ✓</div>`;
      return;
    }
    const isApproval = a => me.role === 'owner' && (
      (a.record_table === 'sales' && a.kind === 'review' && a.title === 'Pending approval') ||
      a.kind === 'customer_change' ||
      (a.kind === 'stock_issue' && a.title.startsWith('Stock change waiting')));
    const item = (a, i) => {
      const btns = [];
      if (isApproval(a)) btns.push(`<button type="button" class="small" data-review="${i}">Review &amp; approve</button>`);
      if (['overdue', 'partial'].includes(a.kind) && a.customer_phone) {
        const text = `Hi ${a.customer_name || ''}, this is Zenvique ${a.outlet || ''}. A friendly reminder: ${a.detail}. ` +
          `Please let us know when you can settle it. Thank you!`;
        btns.push(`<a class="btn small wa" target="_blank" rel="noopener" href="${App.waLink(a.customer_phone, text)}">Send WhatsApp to customer</a>`);
      }
      if (STAFF_FOLLOWUP.includes(a.kind) && a.staff_id && a.staff_id !== me.id) {
        const text = `Hi ${a.staff_name || ''}, please check the sale for ${a.customer_name || 'a customer'} at ${a.outlet || ''}: ` +
          `${a.title}${a.detail ? ' (' + a.detail + ')' : ''}. Thank you!`;
        btns.push(`<a class="btn small wa" target="_blank" rel="noopener" href="${App.waLink(a.staff_phone, text)}">Send WhatsApp to ${App.esc(a.staff_name || 'staff')}</a>`);
      }
      if (a.kind === 'stock' && me.role === 'manager') {
        const text = `Hi, ${a.outlet} needs stock: ${a.detail}. Please arrange a transfer from HQ. Thank you!`;
        btns.push(`<a class="btn small wa" target="_blank" rel="noopener" href="${App.waLink(opts.ownerWhatsapp, text)}">Send WhatsApp to owner</a>`);
      }
      return `<li class="alert ${a.level}">
        <div><span class="tag ${a.level}">${a.level === 'red' ? 'Act now' : 'Watch'}</span>
          <strong>${App.esc(a.title)}</strong>${a.outlet ? ` <span class="muted">· ${App.esc(a.outlet)}</span>` : ''}</div>
        <div class="muted">${App.esc([a.customer_name, a.detail].filter(Boolean).join(' · '))}</div>
        ${btns.length ? `<div class="alert-btns">${btns.join('')}</div>` : ''}
      </li>`;
    };
    const SHOW = 6;
    el.innerHTML = `<div class="alertbox">
      <div class="alert-head"><strong>Alerts</strong>
        <span><span class="tag red">${reds} Act now</span> <span class="tag amber">${ambers} Watch</span></span></div>
      ${App.legendHtml()}
      <ul class="alerts-list">${alerts.slice(0, SHOW).map(item).join('')}</ul>
      ${alerts.length > SHOW ? `<ul class="alerts-list hidden" id="moreAlerts">${alerts.slice(SHOW).map((a, i) => item(a, i + SHOW)).join('')}</ul>
        <button type="button" class="link" id="moreAlertsBtn">Show all ${alerts.length} alerts</button>` : ''}
    </div>`;
    const more = el.querySelector('#moreAlertsBtn');
    if (more) more.addEventListener('click', () => { el.querySelector('#moreAlerts').classList.remove('hidden'); more.remove(); });
    el.querySelectorAll('[data-review]').forEach(b => b.addEventListener('click', () =>
      App.openApproval(alerts[Number(b.dataset.review)], onChange)));
  },

  // Owner: see before -> after and approve or reject
  async openApproval(a, onChange) {
    let dlg = document.getElementById('approvalDlg');
    if (!dlg) {
      dlg = document.createElement('dialog');
      dlg.id = 'approvalDlg';
      dlg.className = 'dlg';
      document.body.appendChild(dlg);
    }
    dlg.innerHTML = '<p class="muted">Loading…</p>';
    dlg.showModal();
    try {
      const names = new Map((await App.fetchAll(() => sb.from('profiles').select('id, full_name, email')))
        .map(p => [p.id, p.full_name || p.email]));
      const show = (k, v) => v === null || v === undefined || v === '' ? '—'
        : /_id$/.test(k) && names.has(v) ? names.get(v) : typeof v === 'boolean' ? (v ? 'Yes' : 'No') : String(v);
      let rows = [], reason = '', title = '', approve, reject;
      if (a.record_table === 'sales') {
        const { data: s, error } = await sb.from('sales').select('id, customer_name, outlet, proposed_change, change_reason, ' +
          Object.keys(App.SALE_FIELDS).join(', ')).eq('id', a.record_id).single();
        if (error) throw error;
        const p = s.proposed_change || {};
        rows = Object.keys(p).filter(k => JSON.stringify(p[k]) !== JSON.stringify(s[k]) && !(p[k] == null && s[k] == null))
          .map(k => [App.SALE_FIELDS[k] || k, show(k, s[k]), show(k, p[k])]);
        reason = s.change_reason; title = `Sale · ${s.customer_name} · ${s.outlet}`;
        approve = () => sb.rpc('approve_sale_change', { p_sale: s.id });
        reject = r => sb.rpc('reject_sale_change', { p_sale: s.id, p_reason: r });
      } else if (a.record_table === 'customers') {
        const { data: c, error } = await sb.from('customers').select('*').eq('id', a.record_id).single();
        if (error) throw error;
        const p = c.proposed_change || {};
        rows = Object.keys(p).filter(k => JSON.stringify(p[k]) !== JSON.stringify(c[k]))
          .map(k => [k.replace(/_/g, ' '), show(k, c[k]), show(k, p[k])]);
        reason = c.change_reason; title = `Customer · ${c.name}`;
        approve = () => sb.rpc('approve_customer_change', { p_customer: c.id });
        reject = r => sb.rpc('reject_customer_change', { p_customer: c.id, p_reason: r });
      } else {
        const { data: s, error } = await sb.from('stock').select('*').eq('id', a.record_id).single();
        if (error) throw error;
        rows = [['Stock issue', s.issue_status, s.proposed_issue_status]];
        reason = s.proposed_issue_note; title = `Stock · ${s.product} · ${s.location}`;
        approve = () => sb.rpc('decide_stock_issue', { p_stock: s.id, p_approve: true, p_reason: null });
        reject = r => sb.rpc('decide_stock_issue', { p_stock: s.id, p_approve: false, p_reason: r });
      }
      dlg.innerHTML = `<h2 style="margin:0 0 4px;font-size:1.1rem">Change waiting for approval</h2>
        <p class="muted" style="margin:0 0 10px">${App.esc(title)}</p>
        <p style="margin:0 0 10px"><strong>Reason:</strong> ${App.esc(reason || '—')}</p>
        ${rows.length ? `<table><thead><tr><th>Field</th><th>Now</th><th>Change to</th></tr></thead><tbody>
          ${rows.map(r => `<tr><td>${App.esc(r[0])}</td><td><span class="before">${App.esc(r[1])}</span></td>
            <td><span class="after">${App.esc(r[2])}</span></td></tr>`).join('')}</tbody></table>`
          : `<p class="muted">${a.record_table === 'sales'
              ? 'No field changes. The manager is asking to mark this sale as reviewed (OK).'
              : 'No field changes found.'}</p>`}
        <label for="rejReason">Reason if rejecting</label><input id="rejReason" type="text">
        <div class="msg" id="dlgMsg"></div>
        <div style="display:flex;gap:8px;justify-content:flex-end;margin-top:14px;flex-wrap:wrap">
          <button type="button" class="ghost" id="dlgClose">Close</button>
          <button type="button" class="danger" id="dlgReject">Reject</button>
          <button type="button" id="dlgApprove">Approve</button>
        </div>`;
      const done = async (fn, okText) => {
        const { error } = await fn();
        if (error) return App.showMsg(dlg.querySelector('#dlgMsg'), App.friendlyError(error), 'error');
        App.showMsg(dlg.querySelector('#dlgMsg'), okText, 'ok');
        setTimeout(() => { dlg.close(); onChange(); }, 700);
      };
      dlg.querySelector('#dlgClose').onclick = () => dlg.close();
      dlg.querySelector('#dlgApprove').onclick = () => done(approve, 'Approved.');
      dlg.querySelector('#dlgReject').onclick = () => {
        const r = dlg.querySelector('#rejReason').value.trim();
        if (!r) return App.showMsg(dlg.querySelector('#dlgMsg'), 'Please write why you are rejecting it.', 'error');
        done(() => reject(r), 'Rejected.');
      };
    } catch (err) {
      dlg.innerHTML = `<p class="msg error">${App.esc(App.friendlyError(err))}</p><button type="button" onclick="this.closest('dialog').close()">Close</button>`;
    }
  },

  // Friendly names for sale fields (approval screen)
  SALE_FIELDS: {
    sale_date: 'Date', customer_name: 'Customer', phone: 'Phone', consultant_id: 'Consultant',
    product_seller_id: 'Product seller', service_staff_id: 'Beautician', service_staff2_id: '2nd beautician',
    treatment: 'Treatment', treatment_amount: 'Treatment RM', product: 'Product', product_qty: 'Qty',
    product_amount: 'Product RM', service: 'Treatment done', service_amount: 'Session RM', discount: 'Discount',
    service_rate_type: 'Rate type', service_rate_pct: 'Rate %', service2_rate_type: '2nd rate type',
    service2_rate_pct: '2nd rate %', voucher_used: 'Voucher used', voucher_code: 'Voucher', referred_by: 'Referred by',
    lead_source: 'Lead source', campaign: 'Campaign', payment_method: 'Payment method', notes: 'Notes',
    transaction_status: 'Transaction status', payment_status: 'Payment status', balance_due: 'Balance owed',
    due_date: 'Due date', customer_id: 'Customer record',
  },

  // Show a message in a box: type = 'error' | 'ok' | 'info'
  showMsg(el, text, type = 'info') {
    if (!el) return;
    el.textContent = text || '';
    el.className = 'msg ' + (text ? type : '');
  },
};
