import { ReactNode } from 'react';
import './dialog.css';

type DialogProps = {
  title: string;
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
};

function Dialog({ title, open, onClose, children, footer }: DialogProps) {
  if (!open) return null;

  return (
    <div className="dialog-backdrop" role="dialog" aria-modal="true">
      <div className="dialog">
        <div className="dialog-head">
          <h3>{title}</h3>
          <button type="button" className="btn btn-ghost" onClick={onClose} aria-label="Close dialog">
            ✕
          </button>
        </div>
        <div className="dialog-body">{children}</div>
        {footer && <div className="dialog-foot">{footer}</div>}
      </div>
    </div>
  );
}

export default Dialog;
