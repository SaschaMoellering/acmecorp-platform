import { builtinEnvironments } from 'vitest/environments';
import type { EnvironmentReturn, VitestEnvironment } from 'vitest';

function ensureArrayBufferAccessors() {
  const abDescriptor = Object.getOwnPropertyDescriptor(ArrayBuffer.prototype, 'resizable');
  if (!abDescriptor) {
    Object.defineProperty(ArrayBuffer.prototype, 'resizable', {
      configurable: true,
      get() {
        return false;
      }
    });
  }

  if (typeof SharedArrayBuffer !== 'undefined') {
    const sabDescriptor = Object.getOwnPropertyDescriptor(SharedArrayBuffer.prototype, 'growable');
    if (!sabDescriptor) {
      Object.defineProperty(SharedArrayBuffer.prototype, 'growable', {
        configurable: true,
        get() {
          return false;
        }
      });
    }
  }
}

const jsdom = builtinEnvironments.jsdom;

const patchedEnvironment: VitestEnvironment = {
  name: 'patched-jsdom',
  transformMode: jsdom.transformMode,
  async setupVM(...args) {
    return jsdom.setupVM(...args);
  },
  async setup(global, options): Promise<EnvironmentReturn> {
    ensureArrayBufferAccessors();
    return jsdom.setup(global, options);
  }
};

export default patchedEnvironment;
