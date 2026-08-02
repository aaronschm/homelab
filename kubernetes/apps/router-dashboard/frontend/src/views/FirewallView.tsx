import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL || '';

export default function FirewallView() {
  const [rules, setRules] = useState<any[]>([]);
  const [natRules, setNatRules] = useState<any[]>([]);
  const [activeTab, setActiveTab] = useState<'filter' | 'nat'>('filter');
  const [showAddNat, setShowAddNat] = useState(false);
  const [newNat, setNewNat] = useState({ protocol: 'tcp', dstPort: '', toAddress: '', toPort: '', comment: '', inInterface: '' });

  const fetchData = () => {
    fetch(`${API_URL}/api/firewall`).then(res => res.json()).then(d => Array.isArray(d) && setRules(d));
    fetch(`${API_URL}/api/firewall/nat`).then(res => res.json()).then(d => Array.isArray(d) && setNatRules(d));
  };

  useEffect(() => { fetchData(); }, []);

  const handleAddNat = async (e: React.FormEvent) => {
    e.preventDefault();
    const res = await fetch(`${API_URL}/api/firewall/nat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newNat)
    });
    const result = await res.json();
    if (result.success) {
      setShowAddNat(false);
      setNewNat({ protocol: 'tcp', dstPort: '', toAddress: '', toPort: '', comment: '', inInterface: '' });
      fetchData();
    } else {
      alert("Error adding NAT rule: " + result.error);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex gap-4">
        <button onClick={() => setActiveTab('filter')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${activeTab === 'filter' ? 'bg-isar text-bgdark' : 'bg-panel text-slate-400 hover:text-slate-200'}`}>Filter Rules</button>
        <button onClick={() => setActiveTab('nat')} className={`px-4 py-2 rounded-lg font-medium transition-colors ${activeTab === 'nat' ? 'bg-isar text-bgdark' : 'bg-panel text-slate-400 hover:text-slate-200'}`}>Port Forwarding (NAT)</button>
      </div>

      <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
        <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50 flex justify-between items-center">
          <h3 className="text-lg font-medium text-white">{activeTab === 'filter' ? 'Firewall Filters' : 'Destination NAT'}</h3>
          {activeTab === 'nat' && (
            <button onClick={() => setShowAddNat(true)} className="bg-isar hover:bg-isar-light text-bgdark font-medium px-4 py-1.5 rounded text-sm transition-colors">+ Add Port Forward</button>
          )}
        </div>
        
        <div className="overflow-x-auto">
          {activeTab === 'filter' ? (
            <table className="w-full text-sm text-left">
              <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
                <tr>
                  <th className="px-6 py-3">#</th>
                  <th className="px-6 py-3">Action</th>
                  <th className="px-6 py-3">Chain</th>
                  <th className="px-6 py-3">Protocol</th>
                  <th className="px-6 py-3">Comment</th>
                </tr>
              </thead>
              <tbody>
                {rules.map((rule, i) => (
                  <tr key={i} className={`border-b border-slate-700/50 hover:bg-slate-800/50 ${rule.disabled === 'true' ? 'opacity-50' : ''}`}>
                    <td className="px-6 py-4 font-mono text-xs text-slate-500">{rule['.id']}</td>
                    <td className="px-6 py-4">
                      <span className={`text-xs px-2 py-1 rounded font-medium ${rule.action === 'accept' || rule.action === 'fasttrack-connection' ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>{rule.action}</span>
                    </td>
                    <td className="px-6 py-4 text-slate-300 font-medium">{rule.chain}</td>
                    <td className="px-6 py-4 font-mono text-xs text-isar">{rule.protocol || 'any'}</td>
                    <td className="px-6 py-4 text-slate-400">{rule.comment || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <table className="w-full text-sm text-left">
              <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
                <tr>
                  <th className="px-6 py-3">Comment</th>
                  <th className="px-6 py-3">Ext. Port</th>
                  <th className="px-6 py-3">Protocol</th>
                  <th className="px-6 py-3">Target IP</th>
                  <th className="px-6 py-3">Target Port</th>
                </tr>
              </thead>
              <tbody>
                {natRules.map((rule, i) => (
                  <tr key={i} className={`border-b border-slate-700/50 hover:bg-slate-800/50 ${rule.disabled === 'true' ? 'opacity-50' : ''}`}>
                    <td className="px-6 py-4 text-white font-medium">{rule.comment || '-'}</td>
                    <td className="px-6 py-4 font-mono text-isar">{rule['dst-port']}</td>
                    <td className="px-6 py-4 text-xs uppercase font-bold text-slate-400">{rule.protocol}</td>
                    <td className="px-6 py-4 font-mono text-slate-300">{rule['to-addresses']}</td>
                    <td className="px-6 py-4 font-mono text-slate-300">{rule['to-ports']}</td>
                  </tr>
                ))}
                {natRules.length === 0 && <tr><td colSpan={5} className="text-center py-6 text-slate-500">No NAT rules found.</td></tr>}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {showAddNat && (
        <div className="fixed inset-0 bg-bgdark/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-panel border border-slate-700 rounded-xl shadow-2xl max-w-md w-full p-6">
            <h3 className="text-xl font-medium text-white mb-4">Add Port Forward</h3>
            <form onSubmit={handleAddNat} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-400 mb-1">Description</label>
                <input type="text" required value={newNat.comment} onChange={e => setNewNat({...newNat, comment: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="e.g. Web Server HTTP" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-400 mb-1">External Port</label>
                  <input type="text" required value={newNat.dstPort} onChange={e => setNewNat({...newNat, dstPort: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="e.g. 80, 443" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400 mb-1">Protocol</label>
                  <select value={newNat.protocol} onChange={e => setNewNat({...newNat, protocol: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar">
                    <option value="tcp">TCP</option>
                    <option value="udp">UDP</option>
                    <option value="tcp,udp">TCP/UDP</option>
                  </select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-400 mb-1">Internal IP</label>
                  <input type="text" required value={newNat.toAddress} onChange={e => setNewNat({...newNat, toAddress: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="10.10.20.x" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400 mb-1">Internal Port</label>
                  <input type="text" required value={newNat.toPort} onChange={e => setNewNat({...newNat, toPort: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="e.g. 8080" />
                </div>
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setShowAddNat(false)} className="px-4 py-2 text-slate-400 hover:text-white transition-colors">Cancel</button>
                <button type="submit" className="bg-isar hover:bg-isar-light text-bgdark font-medium px-6 py-2 rounded transition-colors">Save Rule</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
