import './badge.css';

type Tone = 'neutral' | 'success' | 'warning' | 'danger' | 'info';

type Props = {
  tone?: Tone;
  children: string;
};

const toneMap: Record<Tone, string> = {
  neutral: 'badge-neutral',
  success: 'badge-success',
  warning: 'badge-warning',
  danger: 'badge-danger',
  info: 'badge-info'
};

function Badge({ tone = 'neutral', children }: Props) {
  return <span className={`badge ${toneMap[tone]}`}>{children}</span>;
}

export default Badge;
