import React from 'react'
import { pageDocument, pageWindow } from './browser-runtime'

export class ErrorBoundary extends React.Component {
  state = { error: null }

  static getDerivedStateFromError(error) {
    return { error }
  }

  componentDidCatch(error, errorInfo) {
    console.error('Coro LLDM render error', error, errorInfo)
  }

  render() {
    if (!this.state.error) return this.props.children
    const english = pageDocument()?.documentElement.lang === 'en'
    return (
      <main className="error-boundary" role="alert">
        <p>{english ? 'Something needs another try.' : 'Algo necesita otro intento.'}</p>
        <h1>{english ? 'We could not open this page.' : 'No pudimos abrir esta página.'}</h1>
        <button type="button" onClick={() => pageWindow()?.location.reload()}>
          {english ? 'Reload the page' : 'Recargar la página'}
        </button>
      </main>
    )
  }
}
