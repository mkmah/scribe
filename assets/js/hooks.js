import { getThemePref, updateIndicators, setTheme } from "./theme"

let Hooks = {}

Hooks.ThemeToggle = {
    mounted() {
        const wrapper = this.el

        // Trigger button toggles the menu
        this._onTriggerClick = (e) => {
            e.stopPropagation()
            const menu = wrapper.querySelector("[data-theme-menu]")
            if (!menu) return
            const isVisible = menu.style.display === "block"
            menu.style.display = isVisible ? "none" : "block"
            if (!isVisible) updateIndicators(wrapper, getThemePref())
        }

        // Option buttons set the theme
        this._onOptionClick = (e) => {
            const btn = e.target.closest("[data-theme-option]")
            if (!btn) return
            const val = btn.getAttribute("data-theme-option")
            setTheme(val)
            const menu = wrapper.querySelector("[data-theme-menu]")
            if (menu) menu.style.display = "none"
            updateIndicators(wrapper, val)
        }

        // Close on outside click
        this._onDocClick = (e) => {
            if (!wrapper.contains(e.target)) {
                const menu = wrapper.querySelector("[data-theme-menu]")
                if (menu) menu.style.display = "none"
            }
        }

        // Use event delegation on the wrapper
        wrapper.addEventListener("click", (e) => {
            if (e.target.closest("[data-theme-trigger]")) {
                this._onTriggerClick(e)
            } else if (e.target.closest("[data-theme-option]")) {
                this._onOptionClick(e)
            }
        })

        document.addEventListener("click", this._onDocClick)
    },
    destroyed() {
        if (this._onDocClick) {
            document.removeEventListener("click", this._onDocClick)
        }
    }
}

Hooks.Clipboard = {
    mounted() {
        this.handleEvent("copy-to-clipboard", ({ text: text }) => {
            navigator.clipboard.writeText(text).then(() => {
                this.pushEventTo(this.el, "copied-to-clipboard", { text: text })
                setTimeout(() => {
                    this.pushEventTo(this.el, "reset-copied", {})
                }, 2000)
            })
        })
    }
}

Hooks.ScrollToBottom = {
    mounted() {
        this.scrollToBottom()
        this.observer = new MutationObserver(() => {
            this.scrollToBottom()
        })
        this.observer.observe(this.el, { childList: true, subtree: true })
    },
    updated() {
        this.scrollToBottom()
    },
    destroyed() {
        if (this.observer) {
            this.observer.disconnect()
        }
    },
    scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight
    }
}

Hooks.TimezoneDetect = {
    mounted() {
        this._setTimezone()
    },
    updated() {
        this._setTimezone()
    },
    _setTimezone() {
        try {
            const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
            const el = this.el.querySelector("[data-detected-tz]")
            if (el) el.textContent = tz
        } catch(e) {
            // fallback
        }
    }
}

export default Hooks
