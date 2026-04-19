// Native Title Sync
// 观察 document.title 变化，同步到原生 App 标题栏
// 仅在原生 App 环境生效，桌面浏览器无副作用

(function() {
  if (typeof window.LedgerNative === "undefined") return

  var lastTitle = document.title

  // MutationObserver 监听 <title> 元素变化
  var titleEl = document.querySelector("title")
  if (titleEl && window.MutationObserver) {
    var observer = new MutationObserver(function() {
      var newTitle = document.title
      if (newTitle !== lastTitle) {
        lastTitle = newTitle
        try { window.LedgerNative.setTitle(newTitle) } catch(e) {}
      }
    })
    observer.observe(titleEl, { childList: true })
  }

  // Turbo 页面加载后同步标题
  document.addEventListener("turbo:load", function() {
    var newTitle = document.title
    if (newTitle !== lastTitle) {
      lastTitle = newTitle
      try { window.LedgerNative.setTitle(newTitle) } catch(e) {}
    }
  })

  // 初始同步
  try { window.LedgerNative.setTitle(document.title) } catch(e) {}
})()
