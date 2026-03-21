/**
 * Mobile Layout Controller
 * Handles mobile sidebar, safe areas, and responsive interactions
 * Inspired by Sure project's app-layout controller
 */

// Mobile Layout Controller (vanilla JS, no Stimulus dependency)
class MobileLayoutController {
  constructor() {
    this.sidebar = null;
    this.overlay = null;
    this.isOpen = false;
    this.previousScrollY = 0;
    
    this.init();
  }

  init() {
    document.addEventListener('DOMContentLoaded', () => {
      this.sidebar = document.getElementById('mobile-sidebar');
      this.overlay = document.getElementById('sidebar-overlay');
      
      if (this.sidebar && this.overlay) {
        this.bindEvents();
      }
    });
  }

  bindEvents() {
    // Find all open buttons
    const openButtons = document.querySelectorAll('[data-action*="openSidebar"]');
    openButtons.forEach(btn => {
      btn.addEventListener('click', () => this.openSidebar());
    });

    // Find all close buttons
    const closeButtons = document.querySelectorAll('[data-action*="closeSidebar"]');
    closeButtons.forEach(btn => {
      btn.addEventListener('click', () => this.closeSidebar());
    });

    // Close on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.isOpen) {
        this.closeSidebar();
      }
    });

    // Handle swipe gestures
    this.initSwipeGestures();
  }

  openSidebar() {
    if (!this.sidebar || this.isOpen) return;
    
    this.previousScrollY = window.scrollY;
    this.isOpen = true;
    
    // Open sidebar
    this.sidebar.classList.remove('-translate-x-full');
    this.sidebar.classList.add('translate-x-0');
    
    // Show overlay
    this.overlay.classList.remove('opacity-0', 'pointer-events-none');
    this.overlay.classList.add('opacity-100', 'pointer-events-auto');
    
    // Prevent body scroll
    document.body.classList.add('overflow-hidden');
    
    // Focus first interactive element
    setTimeout(() => {
      const firstLink = this.sidebar.querySelector('a, button');
      if (firstLink) firstLink.focus();
    }, 300);
  }

  closeSidebar() {
    if (!this.sidebar || !this.isOpen) return;
    
    this.isOpen = false;
    
    // Close sidebar
    this.sidebar.classList.remove('translate-x-0');
    this.sidebar.classList.add('-translate-x-full');
    
    // Hide overlay
    this.overlay.classList.remove('opacity-100', 'pointer-events-auto');
    this.overlay.classList.add('opacity-0', 'pointer-events-none');
    
    // Restore body scroll
    document.body.classList.remove('overflow-hidden');
    window.scrollTo(0, this.previousScrollY);
  }

  toggleSidebar() {
    if (this.isOpen) {
      this.closeSidebar();
    } else {
      this.openSidebar();
    }
  }

  initSwipeGestures() {
    let touchStartX = 0;
    let touchEndX = 0;
    const swipeThreshold = 50;

    document.addEventListener('touchstart', (e) => {
      touchStartX = e.changedTouches[0].screenX;
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
      touchEndX = e.changedTouches[0].screenX;
      this.handleSwipeGesture(touchStartX, touchEndX, swipeThreshold);
    }, { passive: true });
  }

  handleSwipeGesture(startX, endX, threshold) {
    const diff = startX - endX;
    
    // Swipe left to close
    if (diff > threshold && this.isOpen) {
      this.closeSidebar();
    }
    
    // Swipe right from edge to open
    if (diff < -threshold && !this.isOpen && startX < 30) {
      this.openSidebar();
    }
  }
}

// Safe Area Handler
class SafeAreaHandler {
  constructor() {
    this.init();
  }

  init() {
    this.updateSafeAreaCSS();
    window.addEventListener('resize', () => this.updateSafeAreaCSS());
  }

  updateSafeAreaCSS() {
    const root = document.documentElement;
    
    // Get computed safe area insets
    const computedStyle = getComputedStyle(root);
    
    // Update CSS variables for components that need them
    const safeAreaTop = computedStyle.getPropertyValue('--safe-area-top') || '0px';
    const safeAreaBottom = computedStyle.getPropertyValue('--safe-area-bottom') || '0px';
    
    root.style.setProperty('--safe-area-top-value', safeAreaTop);
    root.style.setProperty('--safe-area-bottom-value', safeAreaBottom);
  }
}

// Initialize controllers
const mobileLayoutController = new MobileLayoutController();
const safeAreaHandler = new SafeAreaHandler();

// Export for potential external use
if (typeof window !== 'undefined') {
  window.MobileLayoutController = MobileLayoutController;
  window.SafeAreaHandler = SafeAreaHandler;
}