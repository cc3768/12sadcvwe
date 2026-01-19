export function viewAbout({ shell }) {
  shell.setBackVisible(true);
  shell.setHeader({ title:"About", sub:"VibePhone Web", pillText:"v1", pillOk:true });

  shell.mount(`
    <div style="font-weight:900;">VibePhone Web</div>
    <div style="color:var(--muted); margin-top:8px;">
      Phone-style portal for VibeChat + utilities.
    </div>
  `);
}
