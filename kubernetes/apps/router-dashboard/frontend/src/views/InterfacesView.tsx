import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL || '';

export default function InterfacesView() {
  const [interfaces, setInterfaces] = useState<any[]>([]);
  const [bridgePorts, setBridgePorts] = useState<any[]>([]);
  const [activeTab, setActiveTab] = useState<'physical' | 'vlan'>('physical');
  const [editingPvid, setEditingPvid] = useState<string | null>(null);
  const [newPvid, setNewPvid] = useState('');

  const fetchData = () => {
    fetch(`${API_URL}/api/interfaces`).then(res => res.json()).then(d => Array.isArray(d) && setInterfaces(d));
    fetch(`${API_URL}/api/bridge`).then(res => res.json()).then(d => d.ports && setBridgePorts(d.ports));
  };

  useEffect(() => { fetchData(); }, []);

  const savePvid = async (id: string) => {
    await fetch(`${API_URL}/api/bridge/port/pvid`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, pvid: newPvid })
    });
    setEditingPvid(null);
    fetchData();
  };

  return (
    <div className="space-y-6">
      <div className="flex gap-4">
        <button onClick={() => setActiveTab('physical')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${activeTab === 'physical' ? 'bg-isar text-bgdark' : 'bg-panel text-slate-400 hover:text-slate-200'}`}>All Interfaces</button>
        <button onClick={() => setActiveTab('vlan')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${activeTab === 'vlan' ? 'bg-isar text-bgdark' : 'bg-panel text-slate-400 hover:text-slate-200'}`}>Bridge VLANs</button>
      </div>

      <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
        <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50">
          <h3 className="text-lg font-medium text-white">{activeTab === 'physical' ? 'Live Interfaces' : 'Bridge Port VLANs (PVID)'}</h3>
        </div>
        
        {activeTab === 'physical' ? (
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
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
                <tr>
                  <th className="px-6 py-3">Interface</th>
                  <th className="px-6 py-3">Bridge</th>
                  <th className="px-6 py-3">Hardware Offload</th>
                  <th className="px-6 py-3">PVID (Untagged)</th>
                </tr>
              </thead>
              <tbody>
                {bridgePorts.map(port => (
                  <tr key={port['.id']} className="border-b border-slate-700/50 hover:bg-slate-800/50 transition-colors">
                    <td className="px-6 py-4 font-medium text-white">{port.interface}</td>
                    <td className="px-6 py-4 text-slate-300">{port.bridge}</td>
                    <td className="px-6 py-4 text-slate-400">{port['hw-offload'] === 'true' ? 'Yes' : 'No'}</td>
                    <td className="px-6 py-4">
                      {editingPvid === port['.id'] ? (
                        <div className="flex items-center gap-2">
                          <input type="number" min="1" max="4094" value={newPvid} onChange={e => setNewPvid(e.target.value)} className="w-20 bg-slate-900 border border-slate-600 rounded px-2 py-1 text-sm text-white focus:outline-none focus:border-isar" autoFocus onKeyDown={e => e.key === 'Enter' && savePvid(port['.id'])} />
                          <button onClick={() => savePvid(port['.id'])} className="text-isar hover:text-isar-light text-xs font-medium">Save</button>
                          <button onClick={() => setEditingPvid(null)} className="text-slate-400 hover:text-slate-200 text-xs">Cancel</button>
                        </div>
                      ) : (
                        <div className="flex items-center gap-2 group">
                          <span className="font-mono text-isar px-2 py-1 bg-isar/10 rounded">{port.pvid || '1'}</span>
                          <button onClick={() => { setEditingPvid(port['.id']); setNewPvid(port.pvid || '1'); }} className="opacity-0 group-hover:opacity-100 text-xs text-slate-400 hover:text-white transition-opacity">Edit</button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
