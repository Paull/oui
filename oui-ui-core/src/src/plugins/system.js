import {ubus} from './ubus'

export const system = {}

system.getSystemInfo = function() {
  return new Promise(resolve => {
    ubus.call('system', 'info').then(r => {
      resolve(r);
    });
  });
}

system.getBoardInfo = function() {
  return new Promise(resolve => {
    ubus.call('system', 'board').then(r => {
      resolve(r);
    });
  });
}

system.getInfo = function() {
  return new Promise(resolve => {
    ubus.callBatch([
      ['system', 'info'],
      ['system', 'board']
    ]).then(r => {
      resolve(Object.assign({}, r[0], r[1]));
    });
  });
}

system.initList = function() {
  return new Promise(resolve => {
    ubus.call('oui.system', 'init_list').then(r => {
      resolve(r.initscripts);
    });
  });
}

system.initEnabled = function(name) {
  return new Promise(resolve => {
    this.initList().then(list => {
      for (let i = 0; i < list.length; i++) {
        if (list[i].name === name) {
          resolve(list[i].enabled);
          return;
        }
      }
      resolve(false);
    });
  });
}

system.setPassword = function(user, password) {
  return ubus.call('rpc-sys', 'password_set', {user, password})
}

system.reboot = function() {
  return ubus.call('system', 'reboot')
}

export default {
  install(Vue) {
    Vue.prototype.$system = system;
  }
}
