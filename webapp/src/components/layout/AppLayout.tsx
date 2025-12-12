import { ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import logo from '../../assets/logo-acmecorp.svg';
import iconOrders from '../../assets/icon-orders.svg';
import iconCatalog from '../../assets/icon-catalog.svg';
import iconBilling from '../../assets/icon-billing.svg';
import iconNotifications from '../../assets/icon-notifications.svg';
import iconAnalytics from '../../assets/icon-analytics.svg';
import './layout.css';

type Props = {
  children: ReactNode;
};

const navItems = [
  { to: '/', label: 'Dashboard', icon: iconAnalytics },
  { to: '/orders', label: 'Orders', icon: iconOrders },
  { to: '/orders/manage', label: 'Manage Orders', icon: iconOrders },
  { to: '/catalog', label: 'Catalog', icon: iconCatalog },
  { to: '/catalog/manage', label: 'Manage Catalog', icon: iconCatalog },
  { to: '/tools/seed', label: 'Seed Data', icon: iconAnalytics },
  { to: '/analytics', label: 'Analytics', icon: iconAnalytics },
  { to: '/system', label: 'System', icon: iconNotifications }
];

function AppLayout({ children }: Props) {
  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="logo-wrap">
          <img src={logo} alt="AcmeCorp" className="logo" />
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
                <img src={item.icon} alt="" />
                <span>{item.label}</span>
              </NavLink>
            ))}
          </nav>
          <div className="nav-foot">
            <img src={iconBilling} alt="" />
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
