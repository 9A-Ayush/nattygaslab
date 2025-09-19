# Rules — NattyGasLab LIMS (Flutter Project)

These rules MUST be applied to ALL screens, services, and UI components in this project.

---

## UI / Theming
- Use **Material 3** design system.  
- Support **ThemeMode.system** (light/dark mode auto).  
- Allow **manual theme override** persisted in **local storage (SharedPreferences)**.  
- Typography → **GoogleFonts.poppins()** for all text.  
- Colors → follow branding in `context.md`:
  - Primary Blue: #0072BC
  - Primary Green: #66A23F
  - Accent Cyan: #00BCD4
  - Background Light: #F8FAFC
  - Background Dark: #121212

---

## Responsiveness
- Always use **MediaQuery** + **LayoutBuilder** for responsive design.  
- No fixed widths, only sensible **maxWidth** for dialogs/forms.  
- Mobile → single column layouts.  
- Tablet/Desktop → 2–3 column layouts or DataTable style views.  

---

## UX & Data Handling
- **No hardcoded data** — all dynamic content must come from **Firestore**.  
- Show **loading states** (skeletons/spinners) and **empty states**.  
- Lists must support:
  - **Pagination** using `.limit()` + `startAfter`.  
  - **Search with debounce** to reduce reads.  
  - **Filters** where applicable.  

---

## Error Handling
- Always handle errors with **Snackbars** or inline messages.  
- Never crash silently.  
- Show user-friendly error messages, but log developer details in comments.

---

## Cloud Functions
- Annotate where privileged actions must call **Cloud Functions**, such as:  
  - Create User  
  - Generate Report PDF  
  - Generate Invoice  
  - Signed Cloudinary Upload  
- Include **short Firestore index suggestions** in comments where queries require indexes.

---

## Code Structure
- Separate **UI widgets**, **services**, and **dialogs/forms** into different files.  
- Example: `cylinders_screen.dart`, `cylinder_service.dart`, `checkinout_dialog.dart`.  
- Keep logic out of UI → use `services/` folder for Firestore & Cloudinary operations.  

---

✅ Always prepend this file (Universal Rules) to every task prompt.  
