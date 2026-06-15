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
  const searchInput = document.getElementById(config.searchInputId);
  const dropdown = document.getElementById(config.dropdownId);
  const optionsContainer = document.getElementById(config.optionsId);
  const hiddenInput = document.getElementById(config.hiddenInputId);
  const dataSource = config.dataSource || [];
  const onSelect = config.onSelect;

  if (!searchInput || !dropdown || !optionsContainer) return;

  // 防止重复初始化：已绑定过的元素跳过
  if (searchInput.dataset.selectorBound === 'true') return;
  searchInput.dataset.selectorBound = 'true';

  const valueKey = config.valueKey || 'id';
  const nameKey = config.nameKey || 'name';
  const fullNameKey = config.fullNameKey || 'full_name';
  const pinyinKey = config.pinyinKey || 'pinyin';
  const levelKey = config.levelKey || 'level';
  const emptyOption = config.emptyOption;
  const noMatchText = config.noMatchText || '无匹配项';
  const enableLevelIndent = !!config.enableLevelIndent;
  const levelIndentBase = config.levelIndentBase || 12;
  const levelIndentSize = config.levelIndentSize || 16;
  const groupByKey = config.groupByKey;
  const groupLabels = config.groupLabels || {};
  const groupColors = config.groupColors || {};

  let pendingOption = null;
  let isSelecting = false;

  function renderOptions(filterText) {
    const query = (filterText || '').toLowerCase();
    const filtered = dataSource.filter(function(item) {
      if (!query) return true;
      const name = (item[nameKey] || '').toLowerCase();
      const fullName = (item[fullNameKey] || '').toLowerCase();
      const pinyin = (item[pinyinKey] || '').toLowerCase();
      return name.includes(query) || fullName.includes(query) || pinyin.includes(query);
    });

    const rows = [];
    if (emptyOption) {
      const emptyValue = emptyOption.value == null ? '' : String(emptyOption.value);
      const emptyDisplay = emptyOption.display == null ? '' : String(emptyOption.display);
      const emptySelected = hiddenInput && String(hiddenInput.value || '') === emptyValue ? 'bg-blue-50 dark:bg-blue-900/20' : '';
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

    let lastGroup = null;
    filtered.forEach(function(item) {
      if (groupByKey) {
        const currentGroup = item[groupByKey];
        if (currentGroup !== lastGroup) {
          if (lastGroup !== null) rows.push('<div class="border-t border-border dark:border-border-dark my-1"></div>');
          const groupLabel = groupLabels[currentGroup] || currentGroup || '';
          const groupColor = groupColors[currentGroup] || 'text-secondary dark:text-secondary-dark';
          rows.push('<div class="px-3 py-1 text-xs font-medium ' + groupColor + ' uppercase tracking-wide">' + escapeHtml(groupLabel) + '</div>');
          lastGroup = currentGroup;
        }
      }

      const value = item[valueKey] == null ? '' : String(item[valueKey]);
      const display = item[fullNameKey] || item[nameKey] || '';
      const selected = hiddenInput && String(hiddenInput.value) === value ? 'bg-blue-50 dark:bg-blue-900/20' : '';
      const level = enableLevelIndent ? (parseInt(item[levelKey], 10) || 0) : 0;
      const styleAttr = level > 0 ? ' style="padding-left: ' + (level * levelIndentSize + levelIndentBase) + 'px"' : '';
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
            const selectedValue = this.dataset.value || '';
            const selectedItem = dataSource.find(function(item) {
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
            const selectedValue = this.dataset.value || '';
            const selectedItem = dataSource.find(function(item) {
              return String(item[valueKey]) === selectedValue;
            });
            onSelect(selectedValue, selectedItem);
          }
        }
      });
    });
  }

  // 移除 readonly 属性，让输入框可编辑
  searchInput.removeAttribute('readonly');

  function openDropdown() {
    if (!dropdown.classList.contains('hidden')) return;
    dropdown.classList.remove('hidden');
    optionsContainer.innerHTML = renderOptions('');
    bindOptionEvents();
  }

  searchInput.addEventListener('input', function() {
    const query = (searchInput.value || '').toLowerCase();
    if (dropdown.classList.contains('hidden')) {
      dropdown.classList.remove('hidden');
    }
    optionsContainer.innerHTML = renderOptions(query);
    bindOptionEvents();
  });

  searchInput.addEventListener('focus', function() {
    openDropdown();
  });

  searchInput.addEventListener('click', function() {
    openDropdown();
  });

  searchInput.addEventListener('blur', function() {
    setTimeout(function() {
      if (!isSelecting) {
        dropdown.classList.add('hidden');
        restoreSearchInputValue();
      }
    }, 100);
  });

  document.addEventListener('click', function(e) {
    if (isSelecting) return;
    if (!dropdown.contains(e.target) && e.target !== searchInput) {
      dropdown.classList.add('hidden');
      restoreSearchInputValue();
    }
  });

  function restoreSearchInputValue() {
    if (hiddenInput && hiddenInput.value) {
      const selectedItem = dataSource.find(function(item) {
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
  const accountsDataEl = document.getElementById('accounts-data');
  let allAccounts = [];
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
  let categories = categoriesData || [];
  if (!categoriesData) {
    const expenseDataEl = document.getElementById('expense-categories-data');
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
