import './kpi-tile.css';

type Props = {
  label: string;
  value: string | number;
  trend?: string;
  icon?: string;
};

function KpiTile({ label, value, trend, icon }: Props) {
  return (
    <div className="kpi">
      <div className="kpi-header">
        <span className="kpi-label">{label}</span>
        {icon && <img src={icon} alt="" className="kpi-icon" />}
      </div>
      <div className="kpi-value">{value}</div>
      {trend && <div className="kpi-trend">{trend}</div>}
    </div>
  );
}

export default KpiTile;
