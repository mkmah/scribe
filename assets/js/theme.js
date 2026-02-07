// Theme management module
// Exports functions used by the ThemeToggle hook

export function getThemePref() {
    return localStorage.getItem("theme") || "system"
}

export function applyTheme(pref) {
    const systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const isDark = pref === "dark" || (pref === "system" && systemDark)
    document.documentElement.classList.toggle("dark", isDark)
}

export function updateIndicators(wrapper, pref) {
    wrapper.querySelectorAll("[data-theme-option]").forEach(btn => {
        const val = btn.getAttribute("data-theme-option")
        const dot = btn.querySelector("[data-theme-dot]")
        if (dot) {
            dot.classList.toggle("hidden", val !== pref)
        }
    })
}

export function setTheme(value) {
    localStorage.setItem("theme", value)
    applyTheme(value)
}

// Listen for system preference changes
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function() {
    if (getThemePref() === "system") {
        applyTheme("system")
    }
})

// Apply theme immediately on import (runs when app.js loads)
applyTheme(getThemePref())
