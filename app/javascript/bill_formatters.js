function formatMoney(value) {
  var num = parseFloat(value) || 0
  return num.toLocaleString("zh-CN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function formatCurrencyRaw(value) {
  return "¥" + formatMoney(value)
}

window.BillFormatters = {
  formatMoney: formatMoney,
  formatCurrencyRaw: formatCurrencyRaw
}

export { formatMoney, formatCurrencyRaw }
