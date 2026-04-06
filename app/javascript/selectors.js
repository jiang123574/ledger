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
  var filterInput = document.getElementById(config.filterInputId);
  var optionsContainer = document.getElementById(config.optionsId);
  var hiddenInput = document.getElementById(config.hiddenInputId);
  var dataSource = config.dataSource || [];

  if (!searchInput || !dropdown || !optionsContainer) return;

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
  var clearFilterPlaceholderOnFocus = !!config.clearFilterPlaceholderOnFocus;
  var filterPlaceholder = config.filterPlaceholder || '搜索...';

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
      option.addEventListener('click', function() {
        if (hiddenInput) hiddenInput.value = this.dataset.value || '';
        searchInput.value = this.dataset.display || '';
        if (filterInput) filterInput.value = '';
        dropdown.classList.add('hidden');
      });
    });
  }

  function updateOptions() {
    var filterText = filterInput ? filterInput.value : '';
    optionsContainer.innerHTML = renderOptions(filterText);
    bindOptionEvents();
  }

  searchInput.addEventListener('click', function() {
    dropdown.classList.toggle('hidden');
    if (!dropdown.classList.contains('hidden')) {
      updateOptions();
      if (filterInput) filterInput.focus();
    }
  });

  if (filterInput) {
    filterInput.placeholder = filterPlaceholder;
    if (clearFilterPlaceholderOnFocus) {
      filterInput.addEventListener('focus', function() {
        this.placeholder = '';
      });
      filterInput.addEventListener('blur', function() {
        this.placeholder = filterPlaceholder;
      });
    }
    filterInput.addEventListener('input', updateOptions);
  }

  document.addEventListener('click', function(e) {
    if (!dropdown.contains(e.target) && e.target !== searchInput) {
      dropdown.classList.add('hidden');
    }
  });
}

// Generic selector initializer with XSS-safe rendering
function initGenericSelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, dataSource, placeholder) {
  initSelectorWithData({
    searchInputId: searchInputId,
    dropdownId: dropdownId,
    filterInputId: filterInputId,
    optionsId: optionsId,
    hiddenInputId: hiddenInputId,
    dataSource: dataSource || [],
    noMatchText: '无匹配项',
    enableLevelIndent: true,
    clearFilterPlaceholderOnFocus: true,
    filterPlaceholder: placeholder || '搜索...'
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
  // If categoriesData is not provided, try to get from script tag
  if (!categoriesData) {
    var expenseDataEl = document.getElementById('expense-categories-data');
    var incomeDataEl = document.getElementById('income-categories-data');
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

// Export for use in views
window.escapeHtml = escapeHtml;
window.initAccountSelector = initAccountSelector;
window.initCategorySelector = initCategorySelector;
window.initGenericSelector = initGenericSelector;
window.initSelectorWithData = initSelectorWithData;
