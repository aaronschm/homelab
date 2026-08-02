import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL || '';

export default function ClientsView() {
  const [clients, setClients] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingMac, setEditingMac] = useState<string | null>(null);
  const [editName, setEditName] = useState('');

  const fetchData = () => {
    fetch(`${API_URL}/api/clients`)
      .then(res => res.json())
      .then(d => {
        setClients(d);
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, []);

  const saveName = async (mac: string) => {
    await fetch(`${API_URL}/api/clients/name`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ mac, name: editName })
    });
    setEditingMac(null);
    fetchData();
  };

  if (loading) return <div className="text-slate-500">Loading clients...</div>;

  return (
    <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
      <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50 flex justify-between items-center">
        <h3 className="text-lg font-medium text-white">Network Clients (ARP & DHCP)</h3>
        <span className="text-xs font-medium bg-isar/20 text-isar px-2.5 py-1 rounded-full">{clients.length} Devices</span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm text-left">
          <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
            <tr>
              <th className="px-6 py-3">Device Name</th>
              <th className="px-6 py-3">IP Address</th>
              <th className="px-6 py-3">MAC Address</th>
              <th className="px-6 py-3">Type</th>
            </tr>
          </thead>
          <tbody>
            {clients.map(client => (
              <tr key={client.mac} className="border-b border-slate-700/50 hover:bg-slate-800/50 transition-colors">
                <td className="px-6 py-4">
                  {editingMac === client.mac ? (
                    <div className="flex items-center gap-2">
                      <input 
                        type="text" 
                        value={editName} 
                        onChange={e => setEditName(e.target.value)}
                        className="bg-slate-900 border border-slate-600 rounded px-2 py-1 text-sm text-white focus:outline-none focus:border-isar"
                        placeholder="Enter name..."
                        autoFocus
                        onKeyDown={e => e.key === 'Enter' && saveName(client.mac)}
                      />
                      <button onClick={() => saveName(client.mac)} className="text-isar hover:text-isar-light text-xs font-medium">Save</button>
                      <button onClick={() => setEditingMac(null)} className="text-slate-400 hover:text-slate-200 text-xs">Cancel</button>
                    </div>
                  ) : (
                    <div className="flex items-center gap-2 group">
                      <span className="font-medium text-white">
                        {client.customName || client.hostname || <span className="text-slate-500 italic">Unknown Device</span>}
                      </span>
                      <button 
                        onClick={() => { setEditingMac(client.mac); setEditName(client.customName || client.hostname || ''); }}
                        className="opacity-0 group-hover:opacity-100 text-xs text-isar transition-opacity"
                      >
                        Edit
                      </button>
                    </div>
                  )}
                </td>
                <td className="px-6 py-4 font-mono text-xs">{client.ip}</td>
                <td className="px-6 py-4 font-mono text-xs text-slate-400">{client.mac}</td>
                <td className="px-6 py-4">
                  <span className={`text-xs px-2 py-1 rounded-md ${client.type === 'dhcp' ? 'bg-indigo-500/10 text-indigo-400' : 'bg-slate-700/50 text-slate-300'}`}>
                    {client.type.toUpperCase()}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
