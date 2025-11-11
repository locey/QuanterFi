'use client'
import { motion } from 'framer-motion';
import { ConnectButton } from "@rainbow-me/rainbowkit";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { WalletButton } from '@rainbow-me/rainbowkit';
import { FiMenu, FiHome, FiTrendingUp, FiDownload, FiRepeat, FiPercent, FiGift } from 'react-icons/fi';
import { useState } from 'react';
import { cn } from '../utils/cn';

const Header = () => {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const Links = [
    { name: 'Home', path: '/', icon: <FiHome className="w-4 h-4 mr-2" /> },
    { name: 'Strategies', path: '/strategies', icon: <FiTrendingUp className="w-4 h-4 mr-2" /> },
    { name: 'AI Models', path: '/ai-models', icon: <FiDownload className="w-4 h-4 mr-2" /> },
    { name: 'Swap', path: '/swap', icon: <FiRepeat className="w-4 h-4 mr-2" /> },
    { name: 'DeFi', path: '/defi', icon: <FiPercent className="w-4 h-4 mr-2" /> },
    { name: 'Airdrop', path: '/airdrop', icon: <FiGift className="w-4 h-4 mr-2" /> },
  ];

  const pathname = usePathname();

  return (
    <motion.header
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      className="sticky top-0 z-50 bg-black/80 backdrop-blur-lg border-b border-gray-800/50"
    >
      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center gap-2 cursor-pointer transition-transform duration-300 transform-none hover:scale-105">
            <Link href="/" className="text-xl font-bold [text-shadow:0_0_10px_#00f5ffcc]">
              QuantFi
            </Link>
          </div>

          {/* Desktop Navigation */}
          <nav className="hidden md:flex items-center space-x-4">
            {Links.map((link) => {
              const isActive = pathname === link.path;
              return (
                <Link
                  key={link.name}
                  href={link.path}
                  className={cn(
                    "flex items-center px-3 py-2 rounded-md text-sm font-medium transition-all duration-300 group",
                    isActive
                      ? "bg-cyan-500 text-white shadow-lg"
                      : "text-gray-300 hover:bg-gray-700 hover:text-white"
                  )}
                >
                  {link.icon}
                  {link.name}
                </Link>
              );
            })}
          </nav>

          <div className="flex items-center gap-4">
            <div className="glow min-w-[120px]">
              {/* <ConnectButton />
              <WalletButton.Custom wallet="rainbow">
                {({ ready, connect }) => {
                  return (
                    <button
                      type="button"
                      className="flex items-center px-3 py-2 rounded-md text-sm font-medium transition-all duration-300 group bg-cyan-500 text-white shadow-lg transition-transform duration-300 transform-none hover:scale-105"
                      disabled={!ready}
                      onClick={connect}
                    >
                      Connect Wallet
                    </button>
                  );
                }}
              </WalletButton.Custom> */}
              <ConnectButton.Custom>
                {({
                  account,
                  chain,
                  openAccountModal,
                  openChainModal,
                  openConnectModal,
                  authenticationStatus,
                  mounted,
                }) => {
                  // Note: If your app doesn't use authentication, you
                  // can remove all 'authenticationStatus' checks
                  const ready = mounted && authenticationStatus !== 'loading';
                  const connected =
                    ready &&
                    account &&
                    chain &&
                    (!authenticationStatus || authenticationStatus === 'authenticated');

                  return (
                    <div
                      {...(!ready && {
                        'aria-hidden': true,
                        'style': {
                          opacity: 0,
                          pointerEvents: 'none',
                          userSelect: 'none',
                        },
                      })}
                    >
                      {(() => {
                        if (!connected) {
                          return (
                            <button onClick={openConnectModal} type="button">
                              Connect Wallet
                            </button>
                          );
                        }

                        if (chain.unsupported) {
                          return (
                            <button onClick={openChainModal} type="button">
                              Wrong network
                            </button>
                          );
                        }

                        return (
                          <div style={{ display: 'flex', gap: 12 }}>
                            <button
                              onClick={openChainModal}
                              style={{ display: 'flex', alignItems: 'center' }}
                              type="button"
                            >
                              {chain.hasIcon && (
                                <div
                                  style={{
                                    background: chain.iconBackground,
                                    width: 12,
                                    height: 12,
                                    borderRadius: 999,
                                    overflow: 'hidden',
                                    marginRight: 4,
                                  }}
                                >
                                  {chain.iconUrl && (
                                    <img
                                      alt={chain.name ?? 'Chain icon'}
                                      src={chain.iconUrl}
                                      style={{ width: 12, height: 12 }}
                                    />
                                  )}
                                </div>
                              )}
                              {chain.name}
                            </button>

                            <button onClick={openAccountModal} type="button">
                              { account.displayName }
                              { account.displayBalance ? ` (${account.displayBalance})` : '' }
                            </button>
                          </div>
                        );
                      })()}
                    </div>
                  );
                }}
              </ConnectButton.Custom>
            </div>
            {/* Mobile menu button */}
            <button
              className="md:hidden p-2 rounded-lg hover:bg-gray-800 text-gray-400 hover:text-cyan-400 transition-colors duration-200"
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            >
              <FiMenu className="w-6 h-6" />
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Navigation */}
      <motion.div
        initial={false}
        animate={{ height: isMobileMenuOpen ? "auto" : 0 }}
        className="md:hidden overflow-hidden"
      >
        <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3 bg-gray-900/95 backdrop-blur-xl border-t border-gray-800">
          {Links.map((link) => {
            const isActive = pathname === link.path;
            return (
              <Link
                key={link.name}
                href={link.path}
                className={cn(
                  "flex items-center px-3 py-2 rounded-md text-base font-medium transition-colors duration-200",
                  isActive
                    ? "bg-cyan-500/20 text-cyan-400"
                    : "text-gray-300 hover:bg-gray-800 hover:text-cyan-400"
                )}
                onClick={() => setIsMobileMenuOpen(false)}
              >
                {link.icon}
                {link.name}
              </Link>
            );
          })}
        </div>
      </motion.div>
    </motion.header>
  );
};

export default Header;
