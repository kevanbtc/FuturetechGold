// Future Tech Holdings - Website Interactivity
document.addEventListener('DOMContentLoaded', function() {
    
    // Smooth scrolling for navigation links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });

    // Navigation background on scroll
    const nav = document.querySelector('.nav');
    let lastScrollY = window.scrollY;
    
    window.addEventListener('scroll', () => {
        const currentScrollY = window.scrollY;
        
        if (currentScrollY > 100) {
            nav.classList.add('scrolled');
        } else {
            nav.classList.remove('scrolled');
        }
        
        lastScrollY = currentScrollY;
    });

    // Animate chart bars on scroll
    const observerOptions = {
        threshold: 0.5,
        rootMargin: '0px 0px -100px 0px'
    };

    const chartObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const bars = entry.target.querySelectorAll('.chart-bar');
                bars.forEach((bar, index) => {
                    setTimeout(() => {
                        bar.style.transform = 'scaleY(1)';
                        bar.style.transformOrigin = 'bottom';
                    }, index * 200);
                });
            }
        });
    }, observerOptions);

    const chartContainer = document.querySelector('.chart-container');
    if (chartContainer) {
        // Initially hide bars
        document.querySelectorAll('.chart-bar').forEach(bar => {
            bar.style.transform = 'scaleY(0)';
            bar.style.transition = 'transform 0.6s ease';
        });
        chartObserver.observe(chartContainer);
    }

    // Animate feature cards on scroll
    const cardObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    document.querySelectorAll('.feature-card, .compliance-card').forEach(card => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        cardObserver.observe(card);
    });

    // Counter animation for hero stats
    function animateCounter(element, target, duration = 2000) {
        const start = 0;
        const increment = target / (duration / 16);
        let current = start;
        
        const timer = setInterval(() => {
            current += increment;
            if (current >= target) {
                current = target;
                clearInterval(timer);
            }
            
            if (element.textContent.includes('%')) {
                element.textContent = Math.floor(current) + '%';
            } else if (element.textContent.includes('B')) {
                element.textContent = '$' + (current / 1000).toFixed(1) + 'B';
            } else if (element.textContent.includes('t')) {
                element.textContent = Math.floor(current) + 't';
            }
        }, 16);
    }

    // Animate hero stats when they come into view
    const statsObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const statNumbers = entry.target.querySelectorAll('.stat-number');
                statNumbers.forEach(stat => {
                    const text = stat.textContent;
                    if (text.includes('$2B')) {
                        animateCounter(stat, 2000);
                    } else if (text.includes('100t')) {
                        animateCounter(stat, 100);
                    } else if (text.includes('5-10%')) {
                        stat.textContent = '5-10%'; // Keep as is
                    } else if (text.includes('105%')) {
                        animateCounter(stat, 105);
                    }
                });
            }
        });
    }, observerOptions);

    const heroStats = document.querySelector('.hero-stats');
    if (heroStats) {
        statsObserver.observe(heroStats);
    }

    // Form handling for CTA buttons
    document.querySelectorAll('.btn-primary, .nav-cta').forEach(button => {
        button.addEventListener('click', function(e) {
            if (this.textContent.includes('Request Access') || this.textContent.includes('Access Platform')) {
                e.preventDefault();
                showAccessModal();
            }
        });
    });

    document.querySelectorAll('.btn-secondary').forEach(button => {
        button.addEventListener('click', function(e) {
            if (this.textContent.includes('Download Whitepaper')) {
                e.preventDefault();
                downloadWhitepaper();
            } else if (this.textContent.includes('Schedule Consultation')) {
                e.preventDefault();
                scheduleConsultation();
            }
        });
    });

    // Mock functions for user interactions
    function showAccessModal() {
        alert('Access Request\n\nThank you for your interest in FTH-GOLD.\n\nThis is a private placement offering available only to qualified investors.\n\nPlease contact our team at:\n📧 access@futuretechholdings.com\n📞 +971-4-XXX-XXXX\n\nOur compliance team will review your qualification and provide access if eligible.');
    }

    function downloadWhitepaper() {
        alert('Whitepaper Download\n\nThe FTH-GOLD technical whitepaper is available to qualified investors upon completion of initial screening.\n\nPlease contact:\n📧 documents@futuretechholdings.com\n\nRequired: Investor qualification verification');
    }

    function scheduleConsultation() {
        alert('Schedule Consultation\n\nTo schedule a consultation with our investment team:\n\n📧 consultation@futuretechholdings.com\n📞 +971-4-XXX-XXXX\n\nAvailable: Monday-Friday, 9 AM - 6 PM GST\n\nNote: Consultations are available only to pre-qualified investors.');
    }

    // Add loading animation for page transitions
    const pageLoader = document.createElement('div');
    pageLoader.className = 'page-loader';
    pageLoader.innerHTML = '<div class="loader-spinner"></div>';
    document.body.appendChild(pageLoader);

    // Hide loader after page loads
    window.addEventListener('load', () => {
        setTimeout(() => {
            pageLoader.style.opacity = '0';
            setTimeout(() => {
                pageLoader.style.display = 'none';
            }, 300);
        }, 500);
    });

    // Add dynamic background effects
    function createFloatingElements() {
        const hero = document.querySelector('.hero');
        if (!hero) return;

        for (let i = 0; i < 20; i++) {
            const dot = document.createElement('div');
            dot.className = 'floating-dot';
            dot.style.cssText = `
                position: absolute;
                width: 4px;
                height: 4px;
                background: rgba(201, 169, 97, 0.3);
                border-radius: 50%;
                left: ${Math.random() * 100}%;
                top: ${Math.random() * 100}%;
                animation: float-random ${3 + Math.random() * 4}s ease-in-out infinite;
                animation-delay: ${Math.random() * 2}s;
                pointer-events: none;
            `;
            hero.appendChild(dot);
        }
    }

    createFloatingElements();

    // Add CSS animations dynamically
    const style = document.createElement('style');
    style.textContent = `
        .page-loader {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: #ffffff;
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 9999;
            transition: opacity 0.3s ease;
        }

        .loader-spinner {
            width: 40px;
            height: 40px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid var(--primary);
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        @keyframes float-random {
            0%, 100% { transform: translateY(0px) translateX(0px); }
            25% { transform: translateY(-20px) translateX(10px); }
            50% { transform: translateY(-10px) translateX(-5px); }
            75% { transform: translateY(-30px) translateX(15px); }
        }

        .nav.scrolled {
            background: rgba(255, 255, 255, 0.98);
            box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
        }

        .hero-stats {
            animation: slideInUp 0.8s ease 0.5s both;
        }

        .hero-actions {
            animation: slideInUp 0.8s ease 0.7s both;
        }

        @keyframes slideInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
    `;
    document.head.appendChild(style);

    console.log('🏛️ Future Tech Holdings website loaded');
    console.log('💎 FTH-GOLD platform ready');
    console.log('🔒 Dubai DMCC licensed and regulated');
});

// Real-time system status (mock)
function updateSystemStatus() {
    const statusIndicators = {
        coverage: Math.random() * 10 + 100, // 100-110%
        oracles: Math.random() > 0.1 ? 'online' : 'degraded',
        contracts: Math.random() > 0.05 ? 'operational' : 'maintenance'
    };

    // Update any status displays on the page
    console.log('System Status:', statusIndicators);
}

// Update status every 30 seconds
setInterval(updateSystemStatus, 30000);

// Export for testing
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        updateSystemStatus
    };
}