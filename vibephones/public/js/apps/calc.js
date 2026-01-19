export function viewCalc({ shell }) {
  shell.setBackVisible(true);
  shell.setHeader({ title:"Calculator", sub:"Basic", pillText:"ready", pillOk:true });

  let expr = "";

  const root = document.createElement("div");
  root.className = "calcWrap";
  root.innerHTML = `
    <div class="calcDisplay" id="d">0</div>
    <div class="calcGrid" id="g"></div>
  `;

  const d = root.querySelector("#d");
  const g = root.querySelector("#g");

  const keys = ["7","8","9","/","4","5","6","*","1","2","3","-","0",".","C","+","(",")","⌫","="];

  keys.forEach((k) => {
    const b = document.createElement("button");
    b.textContent = k;
    b.onclick = () => press(k);
    g.appendChild(b);
  });

  function press(k){
    if (k === "C") expr = "";
    else if (k === "⌫") expr = expr.slice(0, -1);
    else if (k === "=") {
      try {
        // minimal safe eval: only digits/operators/space/parens/dot
        if (!/^[0-9+\-*/().\s]+$/.test(expr)) throw new Error("bad");
        // eslint-disable-next-line no-new-func
        const v = Function(`"use strict"; return (${expr});`)();
        expr = String(v);
      } catch { expr = "ERR"; }
    } else {
      if (expr === "ERR") expr = "";
      expr += k;
    }
    d.textContent = expr || "0";
  }

  shell.mount(root);
}
