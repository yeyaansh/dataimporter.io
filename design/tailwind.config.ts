// ==========================================================================
// DataPilot — Tailwind CSS v4 theme config (tailwind.config.ts)
// Maps design tokens to Tailwind utilities.
// Usage: bg-surface, text-muted, border-input, ring-accent, etc.
// ==========================================================================

import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{ts,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        bg:            "var(--color-bg)",
        "bg-raised":   "var(--color-bg-raised)",
        surface:       "var(--color-surface)",
        "surface-alt": "var(--color-surface-alt)",
        border:        "var(--color-border)",
        "border-input":"var(--color-border-input)",
        "border-focus":"var(--color-border-focus)",
        text:          "var(--color-text)",
        "text-muted":  "var(--color-text-muted)",
        "text-subtle": "var(--color-text-subtle)",
        "text-inverse":"var(--color-text-inverse)",
        accent: {
          DEFAULT:     "var(--color-accent)",
          hover:       "var(--color-accent-hover)",
          light:       "var(--color-accent-light)",
        },
        "on-accent":   "var(--color-on-accent)",
        danger: {
          DEFAULT:     "var(--color-danger)",
          hover:       "var(--color-danger-hover)",
          light:       "var(--color-danger-light)",
        },
        "on-danger":   "var(--color-on-danger)",
        success: {
          DEFAULT:     "var(--color-success)",
          hover:       "var(--color-success-hover)",
          light:       "var(--color-success-light)",
        },
        "on-success":  "var(--color-on-success)",
        warning: {
          DEFAULT:     "var(--color-warning)",
          light:       "var(--color-warning-light)",
        },
        "on-warning":  "var(--color-on-warning)",
        info: {
          DEFAULT:     "var(--color-info)",
          light:       "var(--color-info-light)",
        },
        sidebar: {
          bg:          "var(--color-sidebar-bg)",
          text:        "var(--color-sidebar-text)",
          active:      "var(--color-sidebar-active)",
          hover:       "var(--color-sidebar-hover)",
        },
      },
      fontFamily: {
        sans: ["var(--font-sans)"],
        mono: ["var(--font-mono)"],
      },
      fontSize: {
        xs:      ["var(--text-xs)",      { lineHeight: "var(--text-xs-lh)" }],
        sm:      ["var(--text-sm)",      { lineHeight: "var(--text-sm-lh)" }],
        base:    ["var(--text-base)",    { lineHeight: "var(--text-base-lh)" }],
        md:      ["var(--text-md)",      { lineHeight: "var(--text-md-lh)" }],
        lg:      ["var(--text-lg)",      { lineHeight: "var(--text-lg-lh)" }],
        xl:      ["var(--text-xl)",      { lineHeight: "var(--text-xl-lh)" }],
        display: ["var(--text-display)", { lineHeight: "var(--text-display-lh)" }],
      },
      borderRadius: {
        sm:   "var(--radius-sm)",
        md:   "var(--radius-md)",
        lg:   "var(--radius-lg)",
        xl:   "var(--radius-xl)",
        "2xl":"var(--radius-2xl)",
        pill: "var(--radius-pill)",
      },
      boxShadow: {
        xs:    "var(--shadow-xs)",
        sm:    "var(--shadow-sm)",
        md:    "var(--shadow-md)",
        lg:    "var(--shadow-lg)",
        pop:   "var(--shadow-pop)",
        focus: "var(--shadow-focus)",
      },
      spacing: {
        "sidebar":     "var(--sidebar-width)",
        "sidebar-sm":  "var(--sidebar-collapsed)",
        "header":      "var(--header-height)",
      },
      maxWidth: {
        "content": "var(--content-max)",
        "wizard":  "var(--wizard-max)",
      },
      transitionDuration: {
        fast: "var(--motion-fast)",
        base: "var(--motion-base)",
        slow: "var(--motion-slow)",
      },
      transitionTimingFunction: {
        ease:   "var(--motion-ease)",
        spring: "var(--motion-spring)",
      },
      zIndex: {
        dropdown: "50",
        sticky:   "100",
        "modal-bg":"200",
        modal:    "300",
        popover:  "400",
        toast:    "500",
      },
    },
  },
  plugins: [],
} satisfies Config;
