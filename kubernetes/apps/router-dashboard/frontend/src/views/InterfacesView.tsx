import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL || '';

export default function InterfacesView() {
  const [interfaces, setInterfaces] = useState<any[]>([]);
  
  useEffect(() => {
    fetch(`${API_URL}/api/interfaces`)
      .then(res => res.json())
      .then(d => {
        if(Array.isArray(d)) setInterfaces(d);
      });
  }, []);

  return (
    <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
      <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50">
        <h3 className="text-lg font-medium text-white">Live Network Interfaces</h3>
      </div>
      <div className="p-6 grid gap-4">
        {interfaces.map((iface, i) => (
          <div key={i} className="flex items-center justify-between p-4 rounded-lg bg-slate-900/50 border border-slate-700/50 hover:border-slate-600 transition-colors">
            <div className="flex items-center gap-4">
              <div className={`w-3 h-3 rounded-full ${iface.running === 'true' ? 'bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' : 'bg-slate-600'}`}></div>
              <div>
                <div className="font-medium text-white text-lg">{iface.name}</div>
                <div className="text-xs text-slate-400 mt-1 uppercase tracking-wider font-semibold">{iface.type}</div>
              </div>
            </div>
            <div className="text-right">
              <div className="text-sm font-mono text-slate-300">MAC: {iface['mac-address'] || 'N/A'}</div>
              <div className="text-xs text-slate-500 mt-1">MTU: {iface['actual-mtu'] || iface.mtu}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
