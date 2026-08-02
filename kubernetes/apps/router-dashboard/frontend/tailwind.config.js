/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        isar: {
          light: '#67e8f9',  // cyan-300
          DEFAULT: '#06b6d4', // cyan-500 (Isar river cyan)
          dark: '#0891b2',   // cyan-600
        },
        bgdark: '#0f172a',    // slate-900
        panel: '#1e293b',     // slate-800
      }
    },
  },
  plugins: [],
}
