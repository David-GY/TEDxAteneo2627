# Core workspace design contract

P01 preserves the supplied prototype's calm Karla typography, neutral surfaces, compact bordered panels, red active navigation and explicit focus. Reference: https://tedx-core-dashboard-demo.vercel.app, inspected from the locally cached HTML source. This is the visual shell; business features are implemented in later steps.

## Tokens and layout

The source of truth is `src/styles/tokens.css`.

| Token | Value / purpose |
| --- | --- |
| Body font | Karla Variable, locally bundled via Fontsource; Arial fallback |
| Background / surface | #f7f7f4 / #ffffff |
| Ink / muted | #252624 / #62665f |
| Divider | #dedfd8 |
| Interface accent / pale accent | #b82320 / #faeeec |
| Focus | #b82320, opaque 3px outline with 3px offset |
| Licensed logo red | #EB0028; reserved, not used to fabricate a logo |
| Controls / panels | Minimum 44px controls; 6px / 10px corners |
| Spacing | 4, 8, 12, 16, 24, 32, 40px |
| Desktop | 236px sidebar, 88px minimum header, 1380px maximum content |
| Mobile | Below 60rem: four labeled destinations and More; scrollable additional navigation |

Use `PageHeading` for one page h1, `Panel` for a named content section, `EmptyState`, `LoadingState`, `ErrorState` for asynchronous states, and `TextField` for a label associated with hint/validation text. Loading uses a polite status; errors have an alert and an explicit recovery action. Required fields say “required”; never convey validation only through color. Preserve long labels through wrapping. Prefer real links for navigation and buttons for actions. No clipped identity labels or icon-only navigation.

## Interaction and boundaries

The first keyboard target skips to the main landmark. More moves focus to Close pages; Escape restores the More button. A route change closes More and focuses main. More is a nonmodal disclosure, not a dialog; it does not trap keyboard focus. Sidebar/mobile navigation is hidden through CSS at its respective breakpoint. Reduced motion is respected.

`navigation.ts` accepts an audience plus explicit capabilities for presentation filtering. This is **not authorization**. Future routes, APIs, RLS and file access must enforce actual permissions independently. Placeholder routes expose no records, including when opened directly. Guest navigation starts with Shared with me. MEAn affiliation is absent from the navigation API. Optional modules remain absent until implemented and enabled.

An approved logo is still needed. Until then, ordinary text identifies the workspace and explicitly labels the pending logo. No member/person fixtures, metrics, fake success buttons, or fabricated committees are included in application routes. The shell says “Workspace preview” and explains its unconnected state. Fictional long labels are injected only by the browser test into its local DOM; they are never compiled into the app.

## Verification

Named P01 assertions are in navigation, shell and route tests, plus `scripts/verify-p01.cjs`. Browser evidence covers 1280px desktop, 320px mobile, long labels, keyboard interaction and 200% zoom metrics (640 CSS pixels at DPR 2 on a 1280px display). This emulates browser zoom reflow; it does not claim a human operated the native browser zoom toolbar or completed assistive-technology UAT. See `docs/build/steps/P01.md` for commands and results.
