import { ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import { logos, icons } from '../../branding';
import './layout.css';

type Props = {
  children: ReactNode;
};

const navItems = [
  { to: '/', label: 'Dashboard', icon: icons.dashboard },
  { to: '/orders', label: 'Orders', icon: icons.services },
  { to: '/orders/manage', label: 'Manage Orders', icon: icons.workloads },
  { to: '/catalog', label: 'Catalog', icon: icons.deployments },
  { to: '/catalog/manage', label: 'Manage Catalog', icon: icons.networking },
  { to: '/invoices', label: 'Invoices', icon: icons.security },
  { to: '/notifications', label: 'Notifications', icon: icons.alerts },
  { to: '/tools/seed', label: 'Seed Data', icon: icons.settings },
  { to: '/analytics', label: 'Analytics', icon: icons.metrics },
  { to: '/system', label: 'System', icon: icons.observability }
];

function AppLayout({ children }: Props) {
  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="logo-wrap">
          <img src={logos.white32} alt="AcmeCorp" className="logo" style={{ height: '28px' }} />
          <div className="brand-copy">
            <span className="brand-name">AcmeCorp Platform</span>
            <span className="brand-tagline">Java. Containers. Clarity.</span>
          </div>
        </div>
      </header>
      <div className="app-body">
        <aside className="app-sidebar">
          <nav className="nav">
            {navItems.map((item) => (
              <NavLink key={item.to} to={item.to} className={({ isActive }) => (isActive ? 'nav-item active' : 'nav-item')}>
                {({ isActive }) => (
                  <>
                    <img src={item.icon} alt="" style={{ width: '18px', height: '18px', opacity: isActive ? 1 : 0.7 }} />
                    <span>{item.label}</span>
                  </>
                )}
              </NavLink>
            ))}
          </nav>
          <div className="nav-foot">
            <img src={icons.networking} alt="" style={{ width: '18px', height: '18px', opacity: 0.7 }} />
            <div>
              <div className="foot-title">Platform</div>
              <div className="foot-sub">Gateway via 8080</div>
            </div>
          </div>
        </aside>
        <main className="app-main">{children}</main>
      </div>
    </div>
  );
}

export default AppLayout;
