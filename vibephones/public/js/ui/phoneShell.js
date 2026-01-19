export function createShell({ root, state, onNavigate, onBack }) {
  root.innerHTML = `
    <div class="phoneWrap">
      <div class="phone">
        <div class="wallpaper"></div>

        <div class="statusBar">
          <div class="sbLeft"><span id="sbTime">--:--</span></div>
          <div class="sbRight">
            <span class="sbPill" id="sbCall">—</span>
          </div>
        </div>

        <div class="appArea">
          <div class="appHeader">
            <div class="left">
              <button class="hBtn" id="btnBack">←</button>
              <div class="titleBlock">
                <div class="title" id="hdrTitle">VibePhone</div>
                <div class="sub" id="hdrSub">Web Portal</div>
              </div>
            </div>
            <div class="pill" id="hdrPill">disconnected</div>
          </div>

          <div class="card scroll" id="appHost"></div>
        </div>
      </div>
    </div>
  `;

  const $ = (id) => document.getElementById(id);

  const elTime = $("sbTime");
  const elCall = $("sbCall");
  const elBack = $("btnBack");
  const elTitle = $("hdrTitle");
  const elSub = $("hdrSub");
  const elPill = $("hdrPill");
  const host = $("appHost");

  function tick() {
    const d = new Date();
    elTime.textContent =
      String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
  }
  tick();
  setInterval(tick, 1000);

  elBack.addEventListener("click", onBack);

  function setHeader({ title, sub, pillText, pillOk }) {
    elTitle.textContent = title ?? "VibePhone";
    elSub.textContent = sub ?? "Web Portal";
    elPill.textContent = pillText ?? "disconnected";
    elPill.style.color = pillOk ? "var(--accent)" : "var(--muted)";
    elPill.style.borderColor = pillOk ? "rgba(92,200,255,.45)" : "rgba(28,42,61,.9)";
  }

  function setCall(call) {
    elCall.textContent = call ? String(call) : "—";
  }

  function setBackVisible(v) {
    elBack.style.visibility = v ? "visible" : "hidden";
  }

  function mount(nodeOrHtml) {
    host.innerHTML = "";
    if (typeof nodeOrHtml === "string") host.innerHTML = nodeOrHtml;
    else host.appendChild(nodeOrHtml);
    host.scrollTop = 0;
  }

  return {
    mount,
    setHeader,
    setCall,
    setBackVisible,
    nav: onNavigate,
  };
}
