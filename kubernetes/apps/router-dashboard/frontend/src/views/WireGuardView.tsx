import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL || '';

export default function WireGuardView() {
  const [data, setData] = useState<{interfaces: any[], peers: any[]}>({ interfaces: [], peers: [] });
  const [loading, setLoading] = useState(true);

  const fetchData = () => {
    fetch(`${API_URL}/api/wireguard`)
      .then(res => res.json())
      .then(d => {
        setData(d);
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, []);

  const toggleInterface = async (id: string, currentlyDisabled: boolean) => {
    await fetch(`${API_URL}/api/wireguard/toggle`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, disabled: !currentlyDisabled })
    });
    fetchData();
  };

  if (loading) return <div className="animate-pulse flex space-x-4"><div className="h-4 bg-slate-700 rounded w-1/4"></div></div>;

  return (
    <div className="space-y-6">
      <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
        <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50">
          <h3 className="text-lg font-medium text-white">WireGuard Interfaces</h3>
        </div>
        <div className="p-6">
          <div className="grid gap-4">
            {data.interfaces.map(iface => (
              <div key={iface['.id']} className="flex items-center justify-between p-4 rounded-lg bg-slate-900/50 border border-slate-700/50 hover:border-slate-600 transition-colors">
                <div>
                  <div className="flex items-center gap-3">
                    <div className={`w-2.5 h-2.5 rounded-full ${iface.disabled === 'false' ? 'bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' : 'bg-rose-500'}`}></div>
                    <span className="font-medium text-white text-lg">{iface.name}</span>
                  </div>
                  <div className="text-sm text-slate-400 mt-1 pl-5.5">Port: {iface['listen-port']} | MTU: {iface.mtu}</div>
                </div>
                <button 
                  onClick={() => toggleInterface(iface['.id'], iface.disabled === 'true')}
                  className={`px-4 py-2 rounded-md font-medium text-sm transition-colors ${iface.disabled === 'false' ? 'bg-rose-500/10 text-rose-500 hover:bg-rose-500/20' : 'bg-emerald-500/10 text-emerald-500 hover:bg-emerald-500/20'}`}
                >
                  {iface.disabled === 'false' ? 'Disable' : 'Enable'}
                </button>
              </div>
            ))}
            {data.interfaces.length === 0 && <div className="text-slate-500 text-center py-4">No WireGuard interfaces found.</div>}
          </div>
        </div>
      </div>

      <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
        <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50">
          <h3 className="text-lg font-medium text-white">Peers</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
              <tr>
                <th className="px-6 py-3">Interface</th>
                <th className="px-6 py-3">Public Key</th>
                <th className="px-6 py-3">Allowed IPs</th>
                <th className="px-6 py-3">Endpoint</th>
              </tr>
            </thead>
            <tbody>
              {data.peers.map(peer => (
                <tr key={peer['.id']} className="border-b border-slate-700/50 hover:bg-slate-800/50 transition-colors">
                  <td className="px-6 py-4 font-medium text-isar">{peer.interface}</td>
                  <td className="px-6 py-4 font-mono text-xs text-slate-400 truncate max-w-xs" title={peer['public-key']}>{peer['public-key']}</td>
                  <td className="px-6 py-4 font-mono text-xs bg-slate-900/30 rounded px-2 py-1 mx-6 my-3 inline-block">{peer['allowed-address']}</td>
                  <td className="px-6 py-4">{peer['endpoint-address'] ? `${peer['endpoint-address']}:${peer['endpoint-port']}` : '-'}</td>
                </tr>
              ))}
              {data.peers.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-6 py-8 text-center text-slate-500">No peers configured.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
