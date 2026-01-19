export class AppState {
  constructor() {
    this.stack = ["home"];
    this.session = this._load("vc_session") || {
      call: null,
      key: null,
      name: "",
      webSecret: "",
    };
    this.chat = {
      room: "#lobby",
      dmTarget: null,
      messages: [],
      directory: [],
      rooms: ["#lobby"],
    };
  }

  _load(k){ try{ return JSON.parse(localStorage.getItem(k)); }catch{ return null; } }
  _save(k,v){ localStorage.setItem(k, JSON.stringify(v)); }

  view(){ return this.stack[this.stack.length - 1]; }

  nav(to){
    if (this.view() === to) return;
    this.stack.push(to);
  }

  back(){
    if (this.stack.length > 1) this.stack.pop();
  }

  setSession(patch){
    Object.assign(this.session, patch);
    this._save("vc_session", this.session);
  }
}
