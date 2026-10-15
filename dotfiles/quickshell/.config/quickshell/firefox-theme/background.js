"use strict";

// Quickshell Theme Sync
// ---------------------
// Reads the palette that the desktop (Quickshell Theme.qml -> apply-theme)
// wrote into theme.json and applies it with the SUPPORTED `theme` WebExtension
// API. That single call themes the browser chrome, menus, sidebar and the new
// tab page (ntp_background / ntp_text / ntp_card_background), which is what
// replaces the old, unsupported `userContent.css` new-tab hacks.

async function readPalette() {
  const url = browser.runtime.getURL("theme.json");
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) {
    throw new Error("theme.json request failed: " + response.status);
  }
  return response.json();
}

async function applyTheme() {
  try {
    const palette = await readPalette();
    await browser.theme.update({
      colors: palette.colors || {},
      properties: palette.properties || {
        color_scheme: "dark",
        content_color_scheme: "dark"
      }
    });
    console.log("[quickshell-theme] palette applied");
  } catch (error) {
    console.error("[quickshell-theme] failed to apply palette:", error);
  }
}

browser.runtime.onInstalled.addListener(applyTheme);
browser.runtime.onStartup.addListener(applyTheme);

// Allow an explicit refresh (e.g. from about:debugging or a future IPC bridge).
browser.runtime.onMessage.addListener((message) => {
  if (message && message.type === "refresh") {
    applyTheme();
  }
});

applyTheme();
