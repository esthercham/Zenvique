// Zenvique language switch: EN | 中文
// Load order on each page: supabase-js CDN → config.js → app.js → i18n.js → page script.
//
// How it works: every page is written in English. This file watches the page and swaps
// each known English text for the chosen language, instantly, without reloading.
// Names, products, treatments, notes and other typed-in data are never in the word list,
// so they are never changed.
//
// To add a language later:
//   1. add it to I18N.languages, e.g. ['ms', 'BM']
//   2. add I18N.dict.ms = { 'English text': 'translation', ... }
//   3. (optional) add I18N.patterns.ms for sentences that contain numbers or names,
//      and I18N.html['key'].ms for the few paragraphs marked data-i18n-html
//   4. allow the new code in supabase/08_language.sql (profiles_language_check)

const I18N = {
  languages: [['en', 'EN'], ['zh', '中文']],
  dict: {},
  patterns: {},
  html: {},
};

// ---------------------------------------------------------------------------
// Simplified Chinese — word list (English → 中文)
// ---------------------------------------------------------------------------
I18N.dict.zh = {
  // Common
  '← Home': '← 主页',
  'Log out': '登出',
  'Loading…': '加载中…',
  'Please wait…': '请稍候…',
  'Save': '保存',
  'Saved.': '已保存。',
  'Saving…': '保存中…',
  'Cancel': '取消',
  'Close': '关闭',
  'Approve': '批准',
  'Reject': '拒绝',
  'Update': '更新',
  'Download': '下载',
  'Nothing changed.': '没有任何更改。',
  'Yes': '是',
  'No': '否',
  'Remove': '移除',
  'Language': '语言',

  // Owner tabs & roles
  'Overview': '总览',
  'Users': '用户',
  'Settings': '设置',
  'History': '历史记录',
  'Manager view': '经理视图',
  'Owner': '老板',
  'Manager': '经理',
  'Staff': '员工',

  // Alerts box & legend
  'Alerts': '提醒',
  'Red': '红色',
  'Amber': '黄色',
  '= Act now': '= 立即处理',
  '= Watch': '= 留意',
  'Act now': '立即处理',
  'Watch': '留意',
  'Nothing needs attention right now. ✓': '目前没有需要处理的事项。✓',
  'Review & approve': '审核并批准',
  'Send WhatsApp to customer': '发 WhatsApp 给顾客',
  'Send WhatsApp to owner': '发 WhatsApp 给老板',
  'staff': '员工',
  'Incomplete sale record': '销售记录不完整',
  'Missing staff on sale': '销售缺少员工',
  'Commission calculation error': '佣金计算错误',
  'Overdue payment': '逾期付款',
  'Partial payment': '部分付款',
  'Payment outstanding': '款项未付',
  'Missing marketing details': '缺少营销资料',
  'Unusually high discount': '折扣异常偏高',
  'Your sale was changed': '你的销售记录被修改了',
  'Critical low stock': '库存严重不足',
  'Low stock': '库存不足',
  'Stock change waiting for approval': '库存变更等待批准',
  'Behind sales target': '落后于销售目标',
  'Customer change waiting for approval': '顾客资料变更等待批准',
  'treatment not named': '疗程未填写名称',
  'product not named': '产品未填写名称',
  'treatment done not named': '已做疗程未填写名称',
  'balance / due date missing': '缺少欠款金额 / 到期日',
  'no Consultant': '没有顾问',
  'no Beautician': '没有美容师',
  'no Product Seller': '没有产品销售员',
  'Saved commission does not match the rates on this sale': '已保存的佣金与这笔销售的费率不符',
  'no lead source': '没有客户来源',
  'referral name missing': '缺少推荐人名字',
  'voucher type / code missing': '缺少礼券类型 / 代码',
  'the owner': '老板',

  // Review reasons & statuses
  'Big discount': '大额折扣',
  'Large sale': '大额销售',
  'Missing details': '资料不全',
  "Stock doesn't tally": '库存对不上',
  'Needs review': '需要审核',
  'Pending approval': '等待批准',
  'OK': '正常',
  'Completed': '已完成',
  'Cancelled': '已取消',
  'Refunded': '已退款',
  'Paid': '已付款',
  'Partial': '部分付款',
  'Outstanding': '未付款',
  'Damaged': '损坏',
  'Expired': '过期',
  'Missing': '遗失',
  'Recount needed': '需要重新盘点',
  'New': '新顾客',
  'Active': '活跃',
  'Follow-up': '待跟进',
  'Inactive': '不活跃',

  // Approval window
  'Change waiting for approval': '变更等待批准',
  'Reason': '原因',
  'Field': '栏位',
  'Now': '目前',
  'Change to': '改为',
  'No field changes. The manager is asking to mark this sale as reviewed (OK).': '没有栏位更改。经理请求把这笔销售标记为已审核（正常）。',
  'No field changes found.': '没有找到栏位更改。',
  'Reason if rejecting': '拒绝的原因',
  'Approved.': '已批准。',
  'Rejected.': '已拒绝。',
  'Please write why you are rejecting it.': '请写下拒绝的原因。',
  'Sale': '销售',
  'Customer': '顾客',
  'Stock': '库存',
  'Stock issue': '库存问题',

  // Sale fields
  'Date': '日期',
  'Phone': '电话',
  'Consultant': '顾问',
  'Product seller': '产品销售员',
  'Product Seller': '产品销售员',
  'Beautician': '美容师',
  '2nd beautician': '第二位美容师',
  'Treatment': '疗程',
  'Treatment RM': '疗程 RM',
  'Product': '产品',
  'Qty': '数量',
  'Product RM': '产品 RM',
  'Treatment done': '已做疗程',
  'Session RM': '单次 RM',
  'Discount': '折扣',
  'Rate type': '费率类型',
  'Rate %': '费率 %',
  '2nd rate type': '第二费率类型',
  '2nd rate %': '第二费率 %',
  'Voucher used': '已用礼券',
  'Voucher': '礼券',
  'Referred by': '推荐人',
  'Lead source': '客户来源',
  'Campaign': '活动',
  'Payment method': '付款方式',
  'Notes': '备注',
  'Transaction status': '交易状态',
  'Payment status': '付款状态',
  'Balance owed': '欠款',
  'Due date': '到期日',
  'Customer record': '顾客记录',
  'customer status': '顾客状态',
  'is vip': 'VIP',
  'phone': '电话',
  'birthday': '生日',
  'notes': '备注',
  'consultant': '顾问',
  'lead source': '客户来源',
  'beautician': '美容师',
  'treatment': '疗程',
  'service': '服务',
  'product': '产品',

  // Friendly error messages (app & database)
  'Email or password is wrong. Please try again.': '电邮或密码错误，请再试一次。',
  'Please confirm your email first. Check your inbox for the link.': '请先确认你的电邮，链接已发到你的邮箱。',
  'This email already has an account. Please log in instead.': '这个电邮已有账户，请直接登录。',
  'Password must be at least 6 characters.': '密码至少需要 6 个字符。',
  'Please enter a valid email address.': '请输入有效的电邮地址。',
  'Too many tries. Please wait a few minutes and try again.': '尝试次数太多，请等几分钟再试。',
  "Can't reach the server. Check your internet and try again.": '无法连接服务器，请检查网络后再试。',
  "You don't have permission to do this.": '你没有权限进行这个操作。',
  'Something went wrong. Please try again.': '出了点问题，请再试一次。',
  'Please write a reason for this change.': '请写下这次更改的原因。',
  "Only a manager's change can be marked as Pending approval.": '只有经理的更改才能标记为等待批准。',
  'Please enter a paid amount or a service done.': '请输入付款金额或已做的服务。',
  "The discount can't be more than the paid amount.": '折扣不能超过付款金额。',
  "The discount can't be more than the sale amount.": '折扣不能超过销售金额。',
  "Please pick the beautician's rate (FULL, FOC or SHARE).": '请选择美容师的费率（FULL、FOC 或 SHARE）。',
  'Please pick the 1st beautician before the 2nd.': '请先选择第一位美容师，再选第二位。',
  'The 2nd beautician must be a different person.': '第二位美容师必须是不同的人。',
  "Please pick the 2nd beautician's rate (FULL, FOC or SHARE).": '请选择第二位美容师的费率（FULL、FOC 或 SHARE）。',
  'Only the owner can approve changes.': '只有老板可以批准更改。',
  'Only the owner can reject changes.': '只有老板可以拒绝更改。',
  'There is no change waiting for approval on this sale.': '这笔销售没有等待批准的更改。',
  'There is no change waiting for approval on this customer.': '这位顾客没有等待批准的更改。',
  'There is no stock change waiting for approval here.': '这里没有等待批准的库存更改。',
  'Only managers and the owner can change customer records.': '只有经理和老板可以更改顾客资料。',
  'Please enter the balance still owed.': '请输入尚欠的金额。',
  'Please enter the due date for the balance.': '请输入欠款的到期日。',
  'This stock item was not found.': '找不到这项库存。',
  'Please pick a valid stock issue status.': '请选择有效的库存问题状态。',
  'Please write a note for this change.': '请为这次更改写备注。',
  'You can only change stock at your own outlet.': '你只能更改自己分店的库存。',
  'You can only save briefs for your own outlet.': '你只能保存自己分店的简报。',
  'Only the owner can change roles, outlets or active status.': '只有老板可以更改角色、分店或启用状态。',

  // Form checks by the browser
  'Please fill in this field.': '请填写这一栏。',
  'Please tick this box.': '请勾选这个方框。',
  'Please pick an item in the list.': '请从列表中选择一项。',
  'Please enter a valid value.': '请输入有效的数值。',
  'Please enter a number.': '请输入数字。',

  // Home / log in
  'Sales, commission & stock': '销售、佣金与库存',
  'Log in': '登录',
  'Create account': '创建账户',
  'Email': '电邮',
  'Password': '密码',
  'Forgot password?': '忘记密码？',
  'Full name': '全名',
  '(at least 6 characters)': '（至少 6 个字符）',
  'New accounts start as Staff. The owner sets your role and outlet.': '新账户默认为员工，老板会设定你的角色和分店。',
  "Enter your email and we'll send you a link to set a new password.": '输入你的电邮，我们会把设定新密码的链接发给你。',
  'Send reset link': '发送重设链接',
  'Back to log in': '返回登录',
  'Set a new password': '设定新密码',
  'New password': '新密码',
  'Save new password': '保存新密码',
  'Your screens': '你的页面',
  'These will be switched on one by one as we build them.': '这些页面会在完成后逐一开放。',
  'My WhatsApp number': '我的 WhatsApp 号码',
  'Used for the "Send WhatsApp" buttons when your manager or the owner needs to reach you.': '当经理或老板需要联系你时，“发 WhatsApp”按钮会用这个号码。',
  'Account created! Check your email and click the confirmation link, then log in here.': '账户已创建！请查看电邮并点击确认链接，然后在这里登录。',
  'If that email has an account, a reset link is on its way. Check your inbox.': '如果这个电邮有账户，重设链接已发出，请查看邮箱。',
  'Password saved. Taking you in…': '密码已保存，正在进入…',
  'All outlets': '所有分店',
  'Your account is switched off. Please contact the owner.': '你的账户已被停用，请联系老板。',
  'You have no outlet yet. Please ask the owner to assign your outlet.': '你还没有分店，请让老板为你分配分店。',
  'Please enter a full phone number.': '请输入完整的电话号码。',
  'New Sale': '新销售',
  'Key in a sale': '输入一笔销售',
  'My Sales & Commission': '我的销售与佣金',
  'This month, my own share': '本月我自己的份额',
  'Manager Dashboard': '经理仪表板',
  'Branch sales, target, stock, lead sources': '分店销售、目标、库存、客户来源',
  'Review List': '审核列表',
  'Needs review & pending approval': '需要审核与等待批准',
  'Outlet stock & low stock': '分店库存与库存不足',
  'Owner Dashboard': '老板仪表板',
  'All outlets, targets, staff, trends': '所有分店、目标、员工、趋势',
  'HQ Stock & Transfers': '总部库存与调货',
  'Move stock from HQ': '从总部调货',
  'Targets, commission, items, reorder levels': '目标、佣金、项目、补货水平',
  'Users & Roles': '用户与角色',
  'Add users, set role, outlet, active': '添加用户，设定角色、分店、启用',
  'Who changed what, before & after': '谁改了什么，改前与改后',
  'Sales, commission, stock, customers (CSV)': '销售、佣金、库存、顾客（CSV）',

  // Manager dashboard
  'Outlet': '分店',
  'Month': '月份',
  'Branch Total Sales': '分店总销售',
  'Sales Target Achievement': '销售目标达成率',
  'My Personal Sales': '我的个人销售',
  'Sales Volume': '交易笔数',
  'completed paid transactions': '已完成的付款交易',
  'Treatment Sales': '疗程销售',
  'personal sales, after discount': '个人销售，折扣后',
  'Product Sales': '产品销售',
  'Service Done': '已做服务',
  'Balance Owed': '欠款',
  'New Customers': '新顾客',
  'first visit to this outlet': '第一次来这家分店',
  'Low Stock Items': '库存不足项目',
  'AI Morning Brief': 'AI 早晨简报',
  'Prepare AI Morning Brief': '准备 AI 早晨简报',
  'Prompt for Claude': '给 Claude 的提示',
  'Copy Prompt': '复制提示',
  'Open Claude': '打开 Claude',
  "Paste Claude's checked response": '粘贴已检查过的 Claude 回复',
  'Paste the brief here after you have checked it against the records.': '对照记录检查后，把简报粘贴在这里。',
  'I have checked this brief': '我已检查这份简报',
  'Save Brief': '保存简报',
  'Last 5 saved briefs': '最近 5 份已保存的简报',
  'This outlet': '这家分店',
  'Sales records': '销售记录',
  'Search customer…': '搜索顾客…',
  'Monthly sales trend (last 6 months)': '每月销售趋势（最近 6 个月）',
  'Treatment breakdown': '疗程明细',
  'Product breakdown': '产品明细',
  'Referral source': '推荐来源',
  'Voucher usage': '礼券使用',
  'New customers': '新顾客',
  'Stock inventory': '库存清单',
  'Customers': '顾客',
  'Search name or phone…': '搜索名字或电话…',
  'Any change you make here is sent to the owner for approval. It takes effect once approved.': '你在这里做的任何更改都会发给老板批准，批准后才生效。',
  'As owner, your changes apply straight away.': '作为老板，你的更改会立即生效。',
  'Nothing this month.': '本月没有记录。',
  'Target reached 🎉': '已达成目标 🎉',
  'No target set for this month yet (the owner sets it).': '本月还没有设定目标（由老板设定）。',
  'not money paid': '不是实收款项',
  'Treatment / package': '疗程 / 配套',
  'Sales': '销售额',
  'Units': '件数',
  'Referral': '推荐',
  'No referrals this month.': '本月没有推荐。',
  'Voucher type / code': '礼券类型 / 代码',
  'Used': '使用次数',
  'No vouchers used this month.': '本月没有使用礼券。',
  'No new customers this month.': '本月没有新顾客。',
  'In stock': '现有库存',
  'Reorder at': '补货点',
  'Issue': '问题',
  'No stock items for this outlet yet.': '这家分店还没有库存项目。',
  '(not named)': '（未命名）',
  '(not filled in)': '（未填写）',
  '(no code)': '（没有代码）',
  'What': '内容',
  'Transaction': '交易',
  'Payment': '付款',
  'Review': '审核',
  'Waiting': '等待中',
  'No sales this month.': '本月没有销售。',
  'Done': '已做',
  'Status': '状态',
  'Birthday': '生日',
  'Visits': '到访次数',
  'Total spend': '总消费',
  'Last visit': '最近到访',
  'change waiting': '变更等待中',
  'No customer matches.': '没有符合的顾客。',
  'No customers yet.': '还没有顾客。',
  'Prompt copied. Paste it into Claude.': '提示已复制，请粘贴到 Claude。',
  'Press Ctrl+C to copy the selected prompt.': '请按 Ctrl+C 复制已选中的提示。',
  "Please paste Claude's checked response first.": '请先粘贴已检查过的 Claude 回复。',
  'Brief saved. It is now read-only.': '简报已保存，现在只能查看。',
  'No briefs saved yet.': '还没有保存的简报。',
  'Show all': '显示全部',
  'Show less': '收起',
  'Edit (owner)': '编辑（老板）',
  'Save edit': '保存编辑',
  '✓ checked': '✓ 已检查',
  'Filters': '筛选条件',
  'Flagged': '已标记',
  'Update sale': '更新销售',
  'Customer status': '顾客状态',
  'VIP': 'VIP',
  'Mark as reviewed (OK)': '标记为已审核（正常）',
  'Cancelled or refunded sales earn no commission, give the product back to stock and are left out of all totals.': '已取消或已退款的销售没有佣金，产品会退回库存，并且不计入所有总额。',
  'Balance owed RM': '欠款 RM',
  'Stock issue status': '库存问题状态',
  'Note': '备注',
  'e.g. 2 bottles broken': '例如：打破 2 瓶',
  'Reason (sent to the owner)': '原因（会发给老板）',
  'e.g. Customer paid the balance today': '例如：顾客今天付清了欠款',
  'Send for approval': '提交批准',
  'Please write a reason for the owner.': '请写下给老板的原因。',
  'Sent to the owner for approval.': '已提交给老板批准。',
  'For Partial or Outstanding, please enter the balance owed and the due date.': '部分付款或未付款时，请输入欠款金额和到期日。',

  // Owner dashboard
  'Period': '期间',
  'Quarter': '季度',
  'Year': '年',
  'All Outlets Total Sales': '所有分店总销售',
  'Target vs Actual': '目标对比实际',
  'paid transactions': '付款交易',
  'Total Commission': '总佣金',
  'all staff': '所有员工',
  'first visit to an outlet': '第一次来某家分店',
  'HQ + all outlets': '总部 + 所有分店',
  'Outlet comparison': '分店比较',
  'Sales trend': '销售趋势',
  'Monthly (12 months)': '每月（12 个月）',
  'Quarterly (8 quarters)': '每季（8 个季度）',
  'Yearly (3 years)': '每年（3 年）',
  'Staff performance': '员工表现',
  'Stock inventory (all locations)': '库存清单（所有地点）',
  'New customers by outlet': '各分店新顾客',
  'Nothing for this period.': '这段期间没有记录。',
  'No targets set. Set them in the Settings tab.': '还没有设定目标，请在“设置”页设定。',
  'reached 🎉': '已达成 🎉',
  'Target': '目标',
  'Achieved': '达成率',
  'Volume': '笔数',
  'Service done': '已做服务',
  'New cust.': '新顾客',
  'Personal sales': '个人销售',
  'Product sold': '已售产品',
  'Services done': '已做服务',
  'Commission': '佣金',
  'Unknown': '未知',
  'No staff activity in this period.': '这段期间没有员工活动。',
  'Total': '总计',
  'No stock items yet.': '还没有库存项目。',
  'No referrals in this period.': '这段期间没有推荐。',
  'No vouchers used in this period.': '这段期间没有使用礼券。',
  'No new customers in this period.': '这段期间没有新顾客。',

  // My sales & commission
  'My Commission': '我的佣金',
  'this month, all outlets': '本月，所有分店',
  'Products I Sold': '我卖出的产品',
  'Services I Did': '我做的服务',
  'Treatment service record': '疗程服务记录',
  'Every treatment I did this month and the rate used.': '我本月做的每个疗程和所用的费率。',
  'My sales this month': '我本月的销售',
  "Sales where I'm the Consultant, Product Seller or Beautician, or that I keyed in.": '我担任顾问、产品销售员或美容师，或由我输入的销售。',
  'Download my sheet (CSV)': '下载我的表格（CSV）',
  'No commission yet this month.': '本月还没有佣金。',
  'No treatments recorded for you this month.': '本月没有你的疗程记录。',
  'Amount': '金额',
  'Com Amt': '佣金',
  'TOTAL': '总计',
  'No sales with your name this month.': '本月没有你名字的销售。',
  'My part': '我的角色',
  'Seller': '销售员',
  'Keyed in': '输入者',

  // New sale
  'When & where': '时间与地点',
  'Find existing customer': '查找现有顾客',
  '(name or phone)': '（名字或电话）',
  'Type at least 2 letters or digits': '至少输入 2 个字母或数字',
  'Customer name': '顾客名字',
  '(new customers, optional)': '（新顾客，可不填）',
  'Paid today (personal sales)': '今天付款（个人销售）',
  'Consultant earns commission on Treatment; Product Seller on Product. Both after discount.': '顾问从疗程赚取佣金；产品销售员从产品赚取佣金。两者都按折扣后计算。',
  'Treatment / package sold': '已售疗程 / 配套',
  'Treatment or package': '疗程或配套',
  'e.g. Hifu 10 sessions': '例如：Hifu 10 次',
  'Discount / Promo RM': '折扣 / 优惠 RM',
  'Balance still owed RM': '尚欠金额 RM',
  'Total paid today': '今天付款总额',
  'Service done today (beautician commission)': '今天已做服务（美容师佣金）',
  "The treatment actually done today. For a package, use the price of one session (e.g. RM798 ÷ 4 sessions = RM199.50). This is not money paid. It's only for service commission.": '今天实际做的疗程。如果是配套，请用一次疗程的价格（例如 RM798 ÷ 4 次 = RM199.50）。这不是实收款项，只用来计算服务佣金。',
  'Session amount RM': '单次金额 RM',
  'e.g. Discovered trt 2/4': '例如：Discovered trt 2/4',
  'Package helper': '配套计算器',
  '(optional: works out the session amount)': '（可选：自动算出单次金额）',
  'Package price RM': '配套价格 RM',
  'Sessions': '次数',
  'e.g. 798': '例如：798',
  'e.g. 4': '例如：4',
  'Rate': '费率',
  '(if shared)': '（如果分担）',
  "2nd beautician's rate": '第二位美容师的费率',
  'How they found us': '顾客如何找到我们',
  'Campaign name': '活动名称',
  'e.g. Nov Glow Promo': '例如：Nov Glow Promo',
  'Referral source / Referred by': '推荐来源 / 推荐人',
  "e.g. customer's name": '例如：顾客名字',
  'Voucher used?': '有用礼券吗？',
  'Pick a type or type a code': '选择类型或输入代码',
  '— None —': '— 无 —',
  '— Pick an outlet —': '— 选择分店 —',
  '— Pick rate —': '— 选择费率 —',
  '— Pick one —': '— 请选择 —',
  '— Pick an outlet first —': '— 请先选择分店 —',
  "You have no outlet yet, so you can't record sales. Please ask the owner to assign your outlet.": '你还没有分店，所以不能记录销售。请让老板为你分配分店。',
  'No match. Type the name and phone below for a new customer.': '没有找到。新顾客请在下面输入名字和电话。',
  'Please pick the date.': '请选择日期。',
  "The date can't be in the future.": '日期不能是未来。',
  'Please pick the outlet.': '请选择分店。',
  'Please enter the customer name.': '请输入顾客名字。',
  'Please fill in Paid today, Service done today, or both.': '请填写“今天付款”、“今天已做服务”或两者。',
  'Please enter how many of the product were sold.': '请输入卖出的产品数量。',
  'Please pick which product was sold.': '请选择卖出的产品。',
  'Please enter which treatment or package was sold.': '请输入卖出的疗程或配套。',
  'Please enter which treatment was done.': '请输入已做的疗程。',
  "Please pick the 2nd beautician's rate.": '请选择第二位美容师的费率。',
  'service recorded (no payment)': '已记录服务（没有付款）',

  // Settings
  'Every change is saved in the History tab with the before and after values.': '每项更改都会连同改前和改后的数值保存在“历史记录”页。',
  'Monthly sales targets': '每月销售目标',
  "Managers see their outlet's target on the Manager Dashboard but can't change it.": '经理可以在经理仪表板看到自己分店的目标，但不能更改。',
  'Save targets': '保存目标',
  'Commission rules': '佣金规则',
  'Consultant: % of Treatment (personal sales)': '顾问：疗程的 %（个人销售）',
  'Product Seller: % of Product': '产品销售员：产品的 %',
  'Both are worked out after discount and rounded down to the sen.': '两者都按折扣后计算，并向下取整到仙。',
  'Beautician service rates (choices shown on New Sale)': '美容师服务费率（在新销售页显示的选项）',
  '+ Add rate': '+ 添加费率',
  'Save commission rules': '保存佣金规则',
  'Treatment, service & product lists': '疗程、服务与产品清单',
  "Prices fill in automatically on New Sale and can still be changed there. A new product gets a stock line (0 in stock) at HQ and every outlet. Renaming a product starts a new stock line, so the old name's stock stays as it was.": '价格会在新销售页自动填入，仍然可以在那里更改。新产品会在总部和每家分店新增一行库存（库存 0）。更改产品名称会新增一行库存，旧名称的库存保持不变。',
  'Treatments / packages': '疗程 / 配套',
  'Services': '服务',
  'Products': '产品',
  '+ Add treatment': '+ 添加疗程',
  '+ Add service': '+ 添加服务',
  '+ Add product': '+ 添加产品',
  'Save lists': '保存清单',
  'Reorder levels': '补货水平',
  'Location': '地点',
  'Save reorder levels': '保存补货水平',
  'Lead sources & voucher types': '客户来源与礼券类型',
  'One per line.': '每行一个。',
  'Lead sources': '客户来源',
  'Voucher types': '礼券类型',
  'Save options': '保存选项',
  'Colour rules & alerts': '颜色规则与提醒',
  'Red: critical low stock at or below (% of reorder level)': '红色：库存严重不足，等于或低于（补货水平的 %）',
  'Red: payment overdue after due date + (days)': '红色：超过到期日 +（天）仍未付款',
  'Amber: branch below (%) of where the target should be by today': '黄色：分店低于今天应达目标的（%）',
  'Amber: unusually high discount above (%)': '黄色：折扣异常偏高，超过（%）',
  'Alerts look back over the last (days)': '提醒回顾最近（天）',
  'Staff told when their sale is changed, within (days)': '员工的销售被修改时通知，期限（天）',
  'Owner\'s WhatsApp number (for managers\' "Send WhatsApp to owner" buttons)': '老板的 WhatsApp 号码（用于经理的“发 WhatsApp 给老板”按钮）',
  'Save colour rules': '保存颜色规则',
  'Review rules': '审核规则',
  'A sale is marked "Needs review" when it goes over these.': '销售超过以下数值时会被标记为“需要审核”。',
  'Big discount: more than (%)': '大额折扣：超过（%）',
  'Large sale: above (RM)': '大额销售：高于（RM）',
  'Save review rules': '保存审核规则',
  'No target': '没有目标',
  'Name': '名字',
  'Price RM': '价格 RM',
  'Please pick a month.': '请选择月份。',
  'Please enter both commission % (0 to 100).': '请输入两个佣金 %（0 到 100）。',
  'Each beautician rate must be between 0 and 10%.': '每个美容师费率必须在 0 到 10% 之间。',
  'Please keep at least one beautician rate.': '请至少保留一个美容师费率。',
  'Saved. New rules apply to sales saved or edited from now on.': '已保存。新规则适用于从现在起保存或编辑的销售。',
  'No stock items here yet.': '这里还没有库存项目。',
  'Please keep at least one lead source.': '请至少保留一个客户来源。',
  'Please enter numbers of 0 or more (percentages up to 100).': '请输入 0 或以上的数字（百分比最多 100）。',
  "Please enter the owner's full phone number.": '请输入老板的完整电话号码。',
  'Please enter both numbers.': '请输入两个数字。',

  // Users & roles
  'Add user': '添加用户',
  'Copy link': '复制链接',
  'Send by WhatsApp': '用 WhatsApp 发送',
  'Search name or email': '搜索名字或电邮',
  'All roles': '所有角色',
  'Needs an outlet': '需要分店',
  'Switched off': '已停用',
  'No one matches.': '没有符合的人。',
  '— No outlet —': '— 没有分店 —',
  '(no name)': '（没有名字）',
  '(you)': '（你）',
  'Role': '角色',
  'Link copied.': '链接已复制。',
  'Press Ctrl+C to copy the selected link.': '请按 Ctrl+C 复制已选中的链接。',
  "You can't remove your own Owner role or switch yourself off.": '你不能取消自己的老板角色或停用自己。',
  'Tip: staff and managers need an outlet before they can record sales.': '提示：员工和经理需要有分店才能记录销售。',

  // History
  'From': '从',
  'To': '到',
  'Everything': '全部',
  'Users & roles': '用户与角色',
  'AI briefs': 'AI 简报',
  'Search': '搜索',
  'Name, email, outlet…': '名字、电邮、分店…',
  'Nothing recorded for these filters.': '这些筛选条件下没有记录。',
  'Reorder level': '补货水平',
  'Consultant %': '顾问 %',
  'Beautician %': '美容师 %',
  'Product seller %': '产品销售员 %',
  'Big discount %': '大额折扣 %',
  'Large sale RM': '大额销售 RM',
  'Issue note': '问题备注',
  'Home outlet': '所属分店',
  'Critical stock %': '库存严重不足 %',
  'Overdue days': '逾期天数',
  'Target warning %': '目标警示 %',
  'High discount %': '高折扣 %',
  'Created': '已创建',
  'Edited': '已编辑',
  'Deleted': '已删除',
  'Status changed': '状态已更改',
  'Approved manager change': '已批准经理的更改',
  'Rejected manager change': '已拒绝经理的更改',
  'User changed': '用户已更改',
  'Settings changed': '设置已更改',
  'Stock moved': '库存已调动',
  'Stock counted': '库存已盘点',
  "Stock count didn't tally": '库存盘点对不上',
  'Reorder level changed': '补货水平已更改',
  'Manager asked for a change': '经理请求更改',
  'Stock issue changed': '库存问题已更改',
  'Manager asked for a stock issue change': '经理请求更改库存问题',
  'User': '用户',
  'AI brief': 'AI 简报',
  'Value': '数值',
  'Added': '已添加',
  'Removed': '已移除',
  'Setting': '设置项',
  'First saved': '首次保存',
  'Review status': '审核状态',
  'Waiting for owner approval. Asked to change:': '等待老板批准。请求更改：',
  'System / SQL Editor': '系统 / SQL 编辑器',

  // Download
  'Files are CSV and open straight in Excel or Google Sheets. Chinese names are kept.': '文件为 CSV 格式，可直接用 Excel 或 Google Sheets 打开，中文名字会保留。',
  'Every sale and service visit with all fields, staff names and status.': '每笔销售和服务到访，包括所有栏位、员工名字和状态。',
  'Commission records': '佣金记录',
  'One line per person per sale or visit: treatment 1%, product 5%, service FULL/FOC/SHARE.': '每人每笔销售或到访一行：疗程 1%、产品 5%、服务 FULL/FOC/SHARE。',
  'Commission summary': '佣金汇总',
  'Per person, per outlet: Treatment, Product and Service commission and total, like the monthly commission sheet.': '按人、按分店：疗程、产品和服务佣金及总额，就像每月佣金表。',
  'Inventory': '库存',
  'Stock today at HQ and every outlet, with reorder levels and low-stock status.': '总部和每家分店今天的库存，包括补货水平和库存不足状态。',
  'Customer records': '顾客记录',
  "The client database: phone, birthday, status, VIP, visits, total spend, first and last visit, lead source. (Dates above don't apply.)": '顾客资料库：电话、生日、状态、VIP、到访次数、总消费、首次和最近到访、客户来源。（上面的日期不适用。）',
  'Lead source data': '客户来源资料',
  'Customers and sales by lead source and outlet.': '按客户来源和分店统计的顾客与销售。',
  'Every sale where a voucher was used.': '每笔使用了礼券的销售。',
  'Preparing…': '准备中…',
  'Please pick a valid date range.': '请选择有效的日期范围。',
  'Downloaded. Check your Downloads folder.': '已下载，请查看“下载”文件夹。',
};

// Sentences with numbers, names or amounts inside. T() translates a piece (or keeps it).
I18N.patterns.zh = [
  [/^Welcome, (.+)$/, m => `欢迎，${m[1]}`],
  [/^(.+) · coming soon$/, (m, T) => `${T(m[1])} · 即将推出`],
  [/^(\d+) Act now$/, m => `${m[1]} 立即处理`],
  [/^(\d+) Watch$/, m => `${m[1]} 留意`],
  [/^Show all (\d+) alerts$/, m => `显示全部 ${m[1]} 条提醒`],
  [/^Send WhatsApp to (.+)$/, (m, T) => `发 WhatsApp 给 ${T(m[1])}`],
  [/^Balance ([\d,.]+) was due (.+)$/, m => `余额 ${m[1]}，原定 ${m[2]} 到期`],
  [/^Balance ([\d,.]+) due (.+)$/, m => `余额 ${m[1]}，${m[2]} 到期`],
  [/^Balance ([\d,.]+)$/, m => `余额 ${m[1]}`],
  [/^Discount ([\d,.]+) = ([\d.]+)% of ([\d,.]+)$/, m => `折扣 ${m[1]} = ${m[3]} 的 ${m[2]}%`],
  [/^Changed by (.+) on (.+)$/, (m, T) => `由 ${T(m[1])} 于 ${m[2]} 修改`],
  [/^(.+): (\d+) left \(reorder at (\d+)\)$/, m => `${m[1]}：剩 ${m[2]}（补货点 ${m[3]}）`],
  [/^Sales ([\d,.]+) of ([\d,.]+) \(([\d.]+)%\); expected by today: ([\d,.]+)$/,
    m => `销售 ${m[1]} / 目标 ${m[2]}（${m[3]}%）；今天应达到：${m[4]}`],
  [/^→ (.+) \(waiting\)$/, (m, T) => `→ ${T(m[1])}（等待中）`],
  [/^([▲▼]) ([\d.]+)% vs (.+)$/, m => `${m[1]} ${m[2]}% 对比 ${m[3]}`],
  [/^Target (RM [\d,.]+)$/, m => `目标 ${m[1]}`],
  [/^Actual (RM [\d,.]+)$/, m => `实际 ${m[1]}`],
  [/^Remaining (RM [\d,.]+)$/i, m => `还差 ${m[1]}`],
  [/^(\d+) transactions? as Consultant$/, m => `作为顾问的 ${m[1]} 笔交易`],
  [/^(\d+) sales? as Consultant$/, m => `作为顾问的 ${m[1]} 笔销售`],
  [/^(\d+) sessions?$/, m => `${m[1]} 次疗程`],
  [/^(\d+) sales? with a balance \(all months\)$/, m => `${m[1]} 笔有欠款的销售（所有月份）`],
  [/^(RM [\d,.]+) due (.+)$/, m => `${m[1]}，${m[2]} 到期`],
  [/^Built from (\d+) sales, (\d+) stock items, (\d+) customers and (\d+) alerts$/,
    m => `根据 ${m[1]} 笔销售、${m[2]} 项库存、${m[3]} 位顾客和 ${m[4]} 条提醒生成`],
  [/^only the newest (\d+) sales are included$/, m => `只包含最新的 ${m[1]} 笔销售`],
  [/^(\d+) sales, (\d+) stock, (\d+) customers, (\d+) alerts$/, m => `${m[1]} 笔销售、${m[2]} 项库存、${m[3]} 位顾客、${m[4]} 条提醒`],
  [/^sales "(.*)"$/, m => `销售“${m[1]}”`],
  [/^customers "(.*)"$/, m => `顾客“${m[1]}”`],
  [/^edited by owner (.+)$/, m => `老板于 ${m[1]} 编辑`],
  [/^by ([^·]+)$/, m => `由 ${m[1]}`],
  [/^Treatment Sale = (.+)$/, m => `疗程销售 = ${m[1]}`],
  [/^Product Sale = (.+)$/, m => `产品销售 = ${m[1]}`],
  [/^Service Comm Total \((\d+) treatments?\)$/, m => `服务佣金总计（${m[1]} 个疗程）`],
  [/^session value ([^·]+)$/, m => `疗程价值 ${m[1]}`],
  [/^(.+) Commission$/, m => `${m[1]} 佣金`],
  [/^= (RM [\d,.]+) per session$/, m => `= 每次 ${m[1]}`],
  [/^(\d+) visits?$/, m => `${m[1]} 次到访`],
  [/^last (\d[^·]*)$/, m => `最近 ${m[1]}`],
  [/^Returning customer: (.+?)( \(VIP\))? · (\d+) visits?, total spend (RM [\d,.]+)(?: · birthday (.+))?$/,
    m => `回头客：${m[1]}${m[2] ? '（VIP）' : ''} · ${m[3]} 次到访，总消费 ${m[4]}${m[5] ? ' · 生日 ' + m[5] : ''}`],
  [/^This will be marked "Needs review" because: (.+)\. You can still save it\.$/, (m, T) => {
    const one = f => {
      let x = f.match(/^discount is more than (.+)%$/); if (x) return `折扣超过 ${x[1]}%`;
      x = f.match(/^total is above (.+)$/); if (x) return `总额高于 ${x[1]}`;
      x = f.match(/^missing (.+)$/); if (x) return '缺少' + x[1].split(', ').map(T).join('、');
      return f;
    };
    return `这笔销售会被标记为“需要审核”，原因：${m[1].split('; ').map(one).join('；')}。你仍然可以保存。`;
  }],
  [/^Saved! (.+?) · (.+?)\.(?: It's marked "Needs review" \((.*)\)\.)? Ready for the next one\.$/, (m, T) => {
    const paid = m[2].match(/^paid (.+)$/);
    const what = paid ? `已付 ${paid[1]}` : T(m[2]);
    const extra = m[3] != null ? `已标记为“需要审核”（${m[3].split(', ').map(T).join('、')}）。` : '';
    return `已保存！${m[1]} · ${what}。${extra}可以输入下一笔了。`;
  }],
  [/^joined (.+)$/, m => `加入于 ${m[1]}`],
  [/^Make (.+) an Owner\? Owners can see and change everything\.$/, m => `要把 ${m[1]} 设为老板吗？老板可以查看和更改所有内容。`],
  [/^(\d+) entr(?:y|ies)$/, m => `${m[1]} 条记录`],
  [/^By (.+)$/, (m, T) => `操作者：${T(m[1])}`],
  [/^(.+): (\d+) from (.+) → (.+)$/, m => `${m[1]}：${m[2]}，从 ${m[3]} → ${m[4]}`],
  [/^(.+): system had (\d+), counted (\d+)$/, m => `${m[1]}：系统有 ${m[2]}，盘点为 ${m[3]}`],
  [/^(.+) at (.+): (\d+) in stock$/, m => `${m[1]}（${m[2]}）：库存 ${m[3]}`],
  [/^Please enter a valid amount for (.+)\.$/, m => `请为 ${m[1]} 输入有效的金额。`],
  [/^Please give every (\w+) a name\.$/, (m, T) => `请为每个${T(m[1])}填写名字。`],
  [/^Please enter a price for "(.+)"\.$/, m => `请为“${m[1]}”输入价格。`],
  [/^"(.+)" is in the (\w+) list twice\.$/, (m, T) => `“${m[1]}”在${T(m[2])}清单里重复了。`],
  [/^Lists saved, but adding stock lines failed: (.+)$/, (m, T) => `清单已保存，但新增库存行失败：${T(m[1])}`],
  [/^Saved\. Added (\d+) new stock lines? \(0 in stock\)\. Set their reorder levels below\.$/,
    m => `已保存。新增了 ${m[1]} 行库存（库存 0）。请在下面设定补货水平。`],
  [/^Please enter a whole number for (.+)\.$/, m => `请为 ${m[1]} 输入整数。`],
  [/^Saved (\d+) changes?\.$/, m => `已保存 ${m[1]} 项更改。`],
  [/^Please use at least (\d+) characters\.$/, m => `请至少输入 ${m[1]} 个字符。`],
  [/^The value must be (.+) or more\.$/, m => `数值必须是 ${m[1]} 或以上。`],
  [/^The value must be (.+) or less\.$/, m => `数值必须是 ${m[1]} 或以下。`],
];

// Paragraphs with bold words or colours inside (marked data-i18n-html="key" on the page)
I18N.html = {
  'sale.intro': {
    zh: '请填写<strong>今天付款</strong>、<strong>今天已做服务</strong>或两者。没有付款的配套疗程，只需填写“今天已做服务”。标有 <span style="color:var(--danger)">*</span> 的栏位是必填的。',
  },
  'dash.briefIntro': {
    zh: '只根据<strong>本页按当前筛选条件显示的记录</strong>，加上今天的日期、这家分店和“设置”里的规则，为 Claude 准备一个问题。顾客电话号码永远不会包含在内。你在 Claude 里运行它，检查答案，然后在这里保存。',
  },
  'users.addIntro': {
    zh: '把这个链接发给新同事。他们点击<strong>创建账户</strong>并确认电邮后，就会以员工身份出现在下面的列表。然后在这里设定他们的角色和分店。',
  },
  'users.listIntro': {
    zh: '设定每个人的角色和分店。员工和经理需要有分店才能记录销售。有人离职时把他们<strong>停用</strong>。他们将无法查看任何内容，但过去的销售会保留。',
  },
  'users.active': { zh: '启用' },
  'settings.reorderIntro': {
    zh: '当某项目的数量等于或低于补货水平时，会显示为<span class="low">库存不足</span>。',
  },
  'settings.colourIntro': {
    zh: '<strong style="color:#b91c1c">红色</strong> = 立即处理 · <strong style="color:#b45309">黄色</strong> = 留意。把某一栏留空即可关闭该规则。',
  },
};

// ---------------------------------------------------------------------------
// Engine (no need to change this when adding words or languages)
// ---------------------------------------------------------------------------
(function () {
  const KEY = 'zv_lang', PENDING = 'zv_lang_pending';
  const codes = I18N.languages.map(l => l[0]);
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} },
    del(k) { try { localStorage.removeItem(k); } catch {} },
  };
  let lang = codes.includes(store.get(KEY)) ? store.get(KEY) : 'en';

  const SKIP = new Set(['SCRIPT', 'STYLE', 'TEXTAREA', 'NOSCRIPT', 'CODE', 'PRE']);
  const ATTRS = ['placeholder', 'title', 'aria-label'];
  const texts = new WeakMap();   // text node -> { orig (English), shown }
  const attrs = new WeakMap();   // element -> { attr: { orig, shown } }
  const htmls = new WeakMap();   // element -> original English HTML
  let cache = new Map();

  // translation -> English (so text the page re-uses after a switch is still recognised)
  const reverse = {};
  for (const c of codes) for (const [en, x] of Object.entries(I18N.dict[c] || {})) {
    if (x !== en && /[^\x00-\x7F]/.test(x) && !(x in reverse)) reverse[x] = en;
  }

  function tr(s) {
    if (lang === 'en' || s == null) return null;
    const key = String(s).replace(/\s+/g, ' ').trim();
    if (!key || !/[A-Za-z]/.test(key)) return null;
    if (cache.has(key)) return cache.get(key);
    cache.set(key, null);                       // guard against loops
    const out = find(key);
    cache.set(key, out);
    return out;
  }
  const T = s => { const x = tr(s); return x == null ? s : x; };

  function find(key) {
    const d = I18N.dict[lang] || {};
    if (Object.prototype.hasOwnProperty.call(d, key)) return d[key];
    for (const [re, fn] of I18N.patterns[lang] || []) {
      const m = key.match(re);
      if (m) { const out = fn(m, T); if (out != null && out !== key) return out; }
    }
    let m = key.match(/^(.+?)\s*:$/);                         // "Label:"
    if (m) { const x = tr(m[1]); if (x != null) return x + '：'; }
    m = key.match(/^([^:]{1,40}):\s+(.+)$/);                  // "Label: value"
    if (m) { const x = tr(m[1]); if (x != null) return x + '：' + T(m[2]); }
    m = key.match(/^(.+) → ([^·]+)$/);                        // "item → Status"
    if (m) { const x = tr(m[2]); if (x != null) return m[1] + ' → ' + x; }
    m = key.match(/^·\s*(.+)$/);                              // "· something"
    if (m) { const x = tr(m[1]); if (x != null) return '· ' + x; }
    if (key.includes(' · ')) {                                // parts joined by " · " (names stay as they are)
      let hit = false;
      const out = key.split(' · ').map(p => { const x = tr(p); if (x != null) { hit = true; return x; } return p; });
      if (hit) return out.join(' · ');
    }
    for (const [sep, join] of [[', ', '、'], ['; ', '；']]) { // lists, only when every item is known
      if (!key.includes(sep)) continue;
      const parts = key.split(sep).map(tr);
      if (parts.every(x => x != null)) return parts.join(join);
    }
    return null;
  }

  function skipped(el) {
    for (; el; el = el.parentElement) {
      if (SKIP.has(el.tagName) || el.hasAttribute('data-no-i18n') || el.hasAttribute('data-i18n-html') || el.isContentEditable) return true;
    }
    return false;
  }

  function doText(n) {
    const cur = n.nodeValue;
    let r = texts.get(n);
    if (!r || cur !== r.shown) {                              // new or changed by the page
      const t = cur.trim(), back = reverse[t];
      r = { orig: back ? cur.replace(t, back) : cur, shown: cur };
      texts.set(n, r);
    }
    let want = r.orig;
    if (lang !== 'en') {
      const x = tr(r.orig);
      if (x != null) want = r.orig.match(/^\s*/)[0] + x + r.orig.match(/\s*$/)[0];
    }
    const p = n.parentNode;                                   // keep <option> values in English
    if (p && p.nodeName === 'OPTION' && !p.hasAttribute('value')) p.setAttribute('value', r.orig.trim());
    r.shown = want;
    if (want !== cur) n.nodeValue = want;
  }

  function doAttrs(el) {
    let rec = attrs.get(el);
    for (const a of ATTRS) {
      if (!el.hasAttribute(a)) continue;
      if (!rec) { rec = {}; attrs.set(el, rec); }
      const cur = el.getAttribute(a);
      let r = rec[a];
      if (!r || cur !== r.shown) r = rec[a] = { orig: reverse[cur] || cur, shown: cur };
      const want = lang === 'en' ? r.orig : T(r.orig);
      r.shown = want;
      if (want !== cur) el.setAttribute(a, want);
    }
  }

  function doHtml(el) {
    if (el.dataset.i18nDone === lang) return;
    if (!htmls.has(el)) htmls.set(el, el.innerHTML);
    const tbl = I18N.html[el.getAttribute('data-i18n-html')] || {};
    el.innerHTML = lang === 'en' ? htmls.get(el) : (tbl[lang] ?? htmls.get(el));
    el.dataset.i18nDone = lang;
  }

  function walk(root) {
    if (root.nodeType === 3) { if (!skipped(root.parentElement)) doText(root); return; }
    if (root.nodeType !== 1) return;
    if (root.parentElement && skipped(root.parentElement)) return;
    if (SKIP.has(root.tagName) || root.hasAttribute('data-no-i18n')) return;
    if (root.hasAttribute('data-i18n-html')) { doHtml(root); return; }
    doAttrs(root);
    const tw = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (n.nodeType === 3) return NodeFilter.FILTER_ACCEPT;
        if (SKIP.has(n.tagName) || n.hasAttribute('data-no-i18n')) return NodeFilter.FILTER_REJECT;
        if (n.hasAttribute('data-i18n-html')) { doHtml(n); return NodeFilter.FILTER_REJECT; }
        return NodeFilter.FILTER_ACCEPT;
      },
    });
    for (let n = tw.nextNode(); n; n = tw.nextNode()) n.nodeType === 3 ? doText(n) : doAttrs(n);
  }

  new MutationObserver(list => {
    for (const m of list) {
      if (m.type === 'childList') m.addedNodes.forEach(walk);
      else if (m.type === 'characterData') {
        const r = texts.get(m.target);
        if (r && m.target.nodeValue === r.shown) continue;    // our own change
        if (!skipped(m.target.parentElement)) doText(m.target);
      } else if (m.type === 'attributes' && !skipped(m.target)) doAttrs(m.target);
    }
  }).observe(document.documentElement, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });

  // Page title, e.g. "New Sale · Zenvique System"
  let titleOrig = null;
  function doTitle() {
    if (titleOrig == null) titleOrig = document.title;
    document.title = lang === 'en' ? titleOrig : titleOrig.split(' · ').map(T).join(' · ');
  }

  // ---------- EN | 中文 buttons ----------
  function makeToggle() {
    const box = document.createElement('div');
    box.className = 'lang-toggle';
    box.setAttribute('data-no-i18n', '');
    box.setAttribute('role', 'group');
    I18N.languages.forEach(([code, label], i) => {
      if (i) { const s = document.createElement('span'); s.className = 'sep'; s.textContent = '|'; box.appendChild(s); }
      const b = document.createElement('button');
      b.type = 'button'; b.textContent = label; b.dataset.lang = code;
      b.addEventListener('click', () => setLang(code));
      box.appendChild(b);
    });
    return box;
  }
  function placeToggles() {
    document.querySelectorAll('.topbar').forEach(bar => {
      if (bar.querySelector('.lang-toggle')) return;
      const right = document.createElement('div');
      right.className = 'topbar-right';
      const last = bar.lastElementChild;
      bar.appendChild(right);
      right.appendChild(makeToggle());
      if (last && last.tagName === 'BUTTON') right.appendChild(last);
    });
    document.querySelectorAll('[data-lang-toggle]').forEach(el => { if (!el.querySelector('.lang-toggle')) el.appendChild(makeToggle()); });
  }
  function markToggles() {
    document.querySelectorAll('.lang-toggle button').forEach(b => {
      const on = b.dataset.lang === lang;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    document.querySelectorAll('.lang-toggle').forEach(g => g.setAttribute('aria-label', lang === 'en' ? 'Language' : T('Language')));
  }

  function applyAll() {
    cache = new Map();
    document.documentElement.lang = lang === 'zh' ? 'zh-CN' : lang;
    if (document.body) walk(document.body);
    doTitle();
    markToggles();
  }

  // ---------- Remember the choice ----------
  async function saveToProfile(code) {
    store.set(PENDING, '1');
    try {
      const { data: { session } } = await sb.auth.getSession();
      if (!session) return;
      const { error } = await sb.from('profiles').update({ language: code }).eq('id', session.user.id);
      if (!error) store.del(PENDING);
    } catch {}
  }
  async function syncFromProfile(session) {
    if (!session) return;
    if (store.get(PENDING)) return saveToProfile(lang);      // chosen before logging in: keep it
    try {
      const { data, error } = await sb.from('profiles').select('language').eq('id', session.user.id).maybeSingle();
      if (error || !data) return;
      if (!data.language) return saveToProfile(lang);
      if (data.language !== lang && codes.includes(data.language)) setLang(data.language, { save: false });
    } catch {}
  }

  function setLang(code, { save = true } = {}) {
    if (!codes.includes(code)) return;
    const changed = code !== lang;
    lang = code;
    store.set(KEY, code);
    if (changed) applyAll(); else markToggles();
    if (save) saveToProfile(code);
  }

  // ---------- Browser form checks and pop-ups in the chosen language ----------
  document.addEventListener('invalid', e => {
    const el = e.target;
    if (!el.setCustomValidity) return;
    el.setCustomValidity('');
    if (lang === 'en') return;
    const v = el.validity;
    let msg = null;
    if (v.valueMissing) msg = el.type === 'checkbox' ? 'Please tick this box.' : el.tagName === 'SELECT' ? 'Please pick an item in the list.' : 'Please fill in this field.';
    else if (v.typeMismatch) msg = el.type === 'email' ? 'Please enter a valid email address.' : 'Please enter a valid value.';
    else if (v.tooShort) msg = `Please use at least ${el.minLength} characters.`;
    else if (v.rangeUnderflow) msg = `The value must be ${el.min} or more.`;
    else if (v.rangeOverflow) msg = `The value must be ${el.max} or less.`;
    else if (v.badInput) msg = 'Please enter a number.';
    else if (v.stepMismatch || v.patternMismatch) msg = 'Please enter a valid value.';
    if (msg) el.setCustomValidity(T(msg));
  }, true);
  ['input', 'change'].forEach(ev => document.addEventListener(ev, e => {
    if (e.target && e.target.setCustomValidity) e.target.setCustomValidity('');
  }, true));
  const _alert = window.alert.bind(window), _confirm = window.confirm.bind(window);
  window.alert = m => _alert(T(String(m)));
  window.confirm = m => _confirm(T(String(m)));

  // ---------- Start ----------
  document.documentElement.lang = lang === 'zh' ? 'zh-CN' : lang;
  document.addEventListener('DOMContentLoaded', () => { placeToggles(); applyAll(); });
  if (window.sb) sb.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' || event === 'INITIAL_SESSION') setTimeout(() => syncFromProfile(session), 0);
  });

  I18N.t = T;
  I18N.setLang = setLang;
  I18N.lang = () => lang;
})();
