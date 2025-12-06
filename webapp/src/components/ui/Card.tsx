import { ReactNode } from 'react';
import './card.css';

type Props = {
  title?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
};

function Card({ title, actions, children }: Props) {
  return (
    <div className="card">
      {(title || actions) && (
        <div className="card-head">
          <div className="card-title">{title}</div>
          {actions && <div className="card-actions">{actions}</div>}
        </div>
      )}
      <div className="card-body">{children}</div>
    </div>
  );
}

export default Card;
