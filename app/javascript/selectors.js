// Shared selector initialization functions
// Used by accounts, plans, budgets, and transactions views

// Escape HTML to prevent XSS
function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Configurable selector initializer
function initSelectorWithData(config) {
  var searchInput = document.getElementById(config.searchInputId);
  var dropdown = document.getElementById(config.dropdownId);
  var optionsContainer = document.getElementById(config.optionsId);
  var hiddenInput = document.getElementById(config.hiddenInputId);
  var dataSource = config.dataSource || [];
  var onSelect = config.onSelect;  // 选择后的回调函数

  if (!searchInput || !dropdown || !optionsContainer) return;

  // 防止重复初始化：已绑定过的元素跳过
  if (searchInput.dataset.selectorBound === 'true') return;
  searchInput.dataset.selectorBound = 'true';

  var valueKey = config.valueKey || 'id';
  var nameKey = config.nameKey || 'name';
  var fullNameKey = config.fullNameKey || 'full_name';
  var pinyinKey = config.pinyinKey || 'pinyin';
  var levelKey = config.levelKey || 'level';
  var emptyOption = config.emptyOption;
  var noMatchText = config.noMatchText || '无匹配项';
  var enableLevelIndent = !!config.enableLevelIndent;
  var levelIndentBase = config.levelIndentBase || 12;
  var levelIndentSize = config.levelIndentSize || 16;

  function renderOptions(filterText) {
    var query = (filterText || '').toLowerCase();
    var filtered = dataSource.filter(function(item) {
      if (!query) return true;
      var name = (item[nameKey] || '').toLowerCase();
      var fullName = (item[fullNameKey] || '').toLowerCase();
      var pinyin = (item[pinyinKey] || '').toLowerCase();
      return name.includes(query) || fullName.includes(query) || pinyin.includes(query);
    });

    var rows = [];
    if (emptyOption) {
      var emptyValue = emptyOption.value == null ? '' : String(emptyOption.value);
      var emptyDisplay = emptyOption.display == null ? '' : String(emptyOption.display);
      var emptySelected = hiddenInput && String(hiddenInput.value || '') === emptyValue ? 'bg-blue-50 dark:bg-blue-900/20' : '';
      rows.push(
        '<div class="selector-option px-3 py-1.5 text-sm cursor-pointer hover:bg-surface dark:hover:bg-surface-dark text-secondary dark:text-secondary-dark ' + emptySelected + '" data-value="' +
          escapeHtml(emptyValue) + '" data-display="' + escapeHtml(emptyDisplay) + '">' +
          escapeHtml(emptyOption.label || '不设置') + '</div>'
      );
    }

    if (filtered.length === 0) {
      rows.push('<div class="px-3 py-2 text-sm text-secondary dark:text-secondary-dark">' + escapeHtml(noMatchText) + '</div>');
      return rows.join('');
    }

    filtered.forEach(function(item) {
      var value = item[valueKey] == null ? '' : String(item[valueKey]);
      var display = item[fullNameKey] || item[nameKey] || '';
      var selected = hiddenInput && String(hiddenInput.value) === value ? 'bg-blue-50 dark:bg-blue-900/20' : '';
      var level = enableLevelIndent ? (parseInt(item[levelKey], 10) || 0) : 0;
      var styleAttr = level > 0 ? ' style="padding-left: ' + (level * levelIndentSize + levelIndentBase) + 'px"' : '';
      rows.push(
        '<div class="selector-option px-3 py-1.5 text-sm cursor-pointer hover:bg-surface dark:hover:bg-surface-dark text-primary dark:text-primary-dark ' +
          selected + '" data-value="' + escapeHtml(value) + '" data-display="' + escapeHtml(display) + '"' + styleAttr + '>' +
          escapeHtml(display) + '</div>'
      );
    });

    return rows.join('');
  }

  function bindOptionEvents() {
    optionsContainer.querySelectorAll('.selector-option').forEach(function(option) {
      option.addEventListener('mousedown', function(e) {
        pendingOption = this;
        isSelecting = true;
        e.preventDefault();
      });

      option.addEventListener('mouseup', function(e) {
        if (pendingOption === this) {
          if (hiddenInput) hiddenInput.value = this.dataset.value || '';
          searchInput.value = this.dataset.display || '';
          dropdown.classList.add('hidden');
          if (onSelect) {
            var selectedValue = this.dataset.value || '';
            var selectedItem = dataSource.find(function(item) {
              return String(item[valueKey]) === selectedValue;
            });
            onSelect(selectedValue, selectedItem);
          }
        }
        pendingOption = null;
        setTimeout(function() { isSelecting = false; }, 50);
      });

      option.addEventListener('click', function(e) {
        if (e.detail === 0) {
          if (hiddenInput) hiddenInput.value = this.dataset.value || '';
          searchInput.value = this.dataset.display || '';
          dropdown.classList.add('hidden');
          if (onSelect) {
            var selectedValue = this.dataset.value || '';
            var selectedItem = dataSource.find(function(item) {
              return String(item[valueKey]) === selectedValue;
            });
            onSelect(selectedValue, selectedItem);
          }
        }
      });
    });
  }

  var pendingOption = null;
  var isSelecting = false;

  // 移除 readonly 属性，让输入框可编辑
  searchInput.removeAttribute('readonly');

  function openDropdown() {
    if (!dropdown.classList.contains('hidden')) return;
    dropdown.classList.remove('hidden');
    // 打开时显示所有选项，不筛选
    optionsContainer.innerHTML = renderOptions('');
    bindOptionEvents();
  }

  // 输入时筛选选项
  searchInput.addEventListener('input', function(e) {
    var query = (searchInput.value || '').toLowerCase();
    // 确保下拉打开
    if (dropdown.classList.contains('hidden')) {
      dropdown.classList.remove('hidden');
    }
    optionsContainer.innerHTML = renderOptions(query);
    bindOptionEvents();
  });

  // 焦点进入时打开下拉
  searchInput.addEventListener('focus', function() {
    openDropdown();
  });

  // 点击时也打开下拉（处理已有焦点时的点击）
  searchInput.addEventListener('click', function() {
    openDropdown();
  });

  // 点击时不做任何事情（不会 toggle 关闭）
  // 点击只用于定位光标位置

  // 点击外部关闭下拉
  document.addEventListener('click', function(e) {
    if (isSelecting) return;
    if (!dropdown.contains(e.target) && e.target !== searchInput) {
      dropdown.classList.add('hidden');
      restoreSearchInputValue();
    }
  });

  // 关闭下拉时恢复 searchInput 的显示值
  function restoreSearchInputValue() {
    if (hiddenInput && hiddenInput.value) {
      var selectedItem = dataSource.find(function(item) {
        return String(item[valueKey]) === String(hiddenInput.value);
      });
      if (selectedItem) {
        searchInput.value = selectedItem[fullNameKey] || selectedItem[nameKey] || '';
      }
    } else if (!hiddenInput || !hiddenInput.value) {
      searchInput.value = '';
    }
  }
}

// Generic selector initializer with XSS-safe rendering
function initGenericSelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, dataSource, placeholder) {
  initSelectorWithData({
    searchInputId: searchInputId,
    dropdownId: dropdownId,
    optionsId: optionsId,
    hiddenInputId: hiddenInputId,
    dataSource: dataSource || [],
    noMatchText: '无匹配项',
    enableLevelIndent: true
  });
}

// Account selector - used across multiple views
function initAccountSelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, placeholder) {
  var accountsDataEl = document.getElementById('accounts-data');
  var allAccounts = [];
  if (accountsDataEl && accountsDataEl.textContent) {
    try {
      allAccounts = JSON.parse(accountsDataEl.textContent);
    } catch (e) {
      console.error('Error parsing accounts data:', e);
    }
  }
  initGenericSelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, allAccounts, placeholder || '搜索账户...');
}

// Category selector - used across multiple views
function initCategorySelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, categoriesData, placeholder) {
  var categories = categoriesData || [];
  if (!categoriesData) {
    var expenseDataEl = document.getElementById('expense-categories-data');
    if (expenseDataEl && expenseDataEl.textContent) {
      try {
        categories = JSON.parse(expenseDataEl.textContent);
      } catch (e) {
        console.error('Error parsing categories data:', e);
      }
    }
  }
  initGenericSelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, categories, placeholder || '搜索分类...');
}

// Export for use in views (both global and ES6 module)
window.escapeHtml = escapeHtml;
window.initAccountSelector = initAccountSelector;
window.initCategorySelector = initCategorySelector;
window.initGenericSelector = initGenericSelector;
window.initSelectorWithData = initSelectorWithData;

export {
  escapeHtml,
  initSelectorWithData,
  initAccountSelector,
  initCategorySelector,
  initGenericSelector
};