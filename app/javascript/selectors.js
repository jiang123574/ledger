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

// Generic selector initializer with XSS-safe rendering
function initGenericSelector(searchInputId, dropdownId, filterInputId, optionsId, hiddenInputId, dataSource, placeholder) {
  var searchInput = document.getElementById(searchInputId);
  var dropdown = document.getElementById(dropdownId);
  var filterInput = document.getElementById(filterInputId);
  var optionsContainer = document.getElementById(optionsId);
  var hiddenInput = document.getElementById(hiddenInputId);

  if (!searchInput || !dropdown || !optionsContainer) return;

  function renderOptions(filterText) {
    var filtered = dataSource.filter(function(item) {
      if (!filterText) return true;
      var query = filterText.toLowerCase();
      if (item.name && item.name.toLowerCase().includes(query)) return true;
      if (item.full_name && item.full_name.toLowerCase().includes(query)) return true;
      if (item.pinyin && item.pinyin.includes(query)) return true;
      return false;
    });

    if (filtered.length === 0) {
      return '<div class="px-3 py-2 text-sm text-secondary dark:text-secondary-dark">无匹配项</div>';
    }

    return filtered.map(function(item) {
      var displayName = item.full_name || item.name;
      var indent = item.level ? 'padding-left: ' + (item.level * 16 + 12) + 'px' : '';
      var selected = hiddenInput && hiddenInput.value == item.id ? 'bg-blue-50 dark:bg-blue-900/20' : '';
      // Use dataset to avoid XSS - safer than string concatenation
      var div = document.createElement('div');
      div.className = 'selector-option px-3 py-1.5 text-sm cursor-pointer hover:bg-surface dark:hover:bg-surface-dark text-primary dark:text-primary-dark ' + selected;
      if (indent) div.style.cssText = indent;
      div.dataset.id = item.id;
      div.dataset.name = displayName;
      div.textContent = displayName;
      return div.outerHTML;
    }).join('');
  }

  function updateOptions() {
    var filterText = filterInput ? filterInput.value : '';
    optionsContainer.innerHTML = renderOptions(filterText);

    optionsContainer.querySelectorAll('.selector-option').forEach(function(option) {
      option.addEventListener('click', function() {
        var id = this.dataset.id;
        var name = this.dataset.name;
        if (hiddenInput) hiddenInput.value = id;
        if (searchInput) searchInput.value = name;
        if (dropdown) dropdown.classList.add('hidden');
        if (filterInput) filterInput.value = '';
      });
    });
  }

  if (searchInput) {
    searchInput.addEventListener('click', function() {
      dropdown.classList.toggle('hidden');
      if (!dropdown.classList.contains('hidden')) {
        updateOptions();
        if (filterInput) filterInput.focus();
      }
    });
  }

  if (filterInput) {
    filterInput.addEventListener('focus', function() {
      this.placeholder = '';
    });
    filterInput.addEventListener('blur', function() {
      this.placeholder = placeholder || '搜索...';
    });
    filterInput.addEventListener('input', function() {
      updateOptions();
    });
  }

  document.addEventListener('click', function(e) {
    if (dropdown && !dropdown.contains(e.target) && e.target !== searchInput) {
      dropdown.classList.add('hidden');
    }
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