// Variation B "Dusk Edit" — light mode screen mocks
// Lifted from the design system, simplified, scoped to Variation B only.

const VB = {
  bg:        '#F7F5F3',
  surface:   '#FFFFFF',
  surface2:  '#F2F0EE',
  border:    '#EBEBEB',
  text:      '#1A1310',
  textSub:   '#7A6E68',
  textMuted: '#B0A8A2',
  accent:    '#FF7043',
  accentSoft:'#FDEAE4',
  grad:      'linear-gradient(135deg, #FF7043 0%, #FF5252 50%, #FF8A80 100%)',
  shadowSm:  '0 1px 6px rgba(0,0,0,0.08)',
  shadowCta: '0 4px 20px rgba(255,112,67,0.27)',
  font:      "'DM Sans', sans-serif",
  fontHead:  "'Plus Jakarta Sans', sans-serif",
};

function VBLogo({ onGradient = false, size = 15 }) {
  const box = size * 2.2;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <div style={{
        width: box, height: box, borderRadius: box * 0.27,
        background: onGradient ? 'rgba(255,255,255,0.9)' : VB.grad,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
      }}>
        <svg width={box*0.6} height={box*0.6} viewBox="0 0 24 24" fill="none">
          <path d="M3 9.5L12 3l9 6.5V21H3V9.5z" fill={onGradient ? VB.accent : 'white'} />
          <rect x="9" y="14" width="6" height="7" rx="1" fill={onGradient ? 'rgba(255,112,67,0.35)' : 'rgba(255,255,255,0.5)'} />
        </svg>
      </div>
      <span style={{
        fontFamily: VB.fontHead, fontWeight: 800, fontSize: size,
        color: onGradient ? '#fff' : VB.text, letterSpacing: '-0.3px',
      }}>ViewxRent</span>
    </div>
  );
}

function VBSearchBar({ onGradient = false, hint = 'Search location or property...' }) {
  return (
    <div style={{
      background: onGradient ? 'rgba(255,255,255,0.15)' : '#fff',
      borderRadius: 50, padding: '10px 16px',
      display: 'flex', alignItems: 'center', gap: 10,
      border: `1px solid ${onGradient ? 'rgba(255,255,255,0.25)' : VB.border}`,
      boxShadow: onGradient ? 'none' : VB.shadowSm,
    }}>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke={onGradient ? 'rgba(255,255,255,0.7)' : VB.textMuted} strokeWidth="2.5" strokeLinecap="round">
        <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
      </svg>
      <span style={{ flex: 1, fontSize: 12, color: onGradient ? 'rgba(255,255,255,0.6)' : VB.textMuted, fontFamily: VB.font }}>{hint}</span>
      <div style={{
        background: onGradient ? 'rgba(255,255,255,0.15)' : VB.surface2,
        borderRadius: 8, padding: '4px 8px',
        display: 'flex', alignItems: 'center',
      }}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
          stroke={onGradient ? '#fff' : VB.accent} strokeWidth="2.5" strokeLinecap="round">
          <line x1="4" y1="6" x2="20" y2="6"/><line x1="8" y1="12" x2="16" y2="12"/><line x1="11" y1="18" x2="13" y2="18"/>
        </svg>
      </div>
    </div>
  );
}

function VBChip({ label, active }) {
  return (
    <div style={{
      padding: '6px 14px', borderRadius: 50, whiteSpace: 'nowrap',
      background: active ? VB.accent : VB.surface2,
      border: `1px solid ${active ? VB.accent : VB.border}`,
      fontSize: 11, fontWeight: active ? 700 : 500,
      color: active ? '#fff' : VB.text, fontFamily: VB.font, flexShrink: 0,
    }}>{label}</div>
  );
}

// HORIZONTAL property card (the Variation B move)
function VBPropertyCard({ img, title, loc, price, beds, baths, area, label }) {
  return (
    <div style={{
      background: VB.surface, borderRadius: 16, overflow: 'hidden',
      boxShadow: VB.shadowSm, border: `1px solid ${VB.border}`,
      display: 'flex', height: 110,
    }}>
      <div style={{ width: 110, flexShrink: 0, position: 'relative', background: '#E5E0DD' }}>
        <img src={img} alt={title} style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          onError={e => { e.target.style.display = 'none'; }} />
        {label && (
          <div style={{
            position: 'absolute', top: 8, left: 8,
            background: VB.accent, color: '#fff',
            fontSize: 8, fontWeight: 700, padding: '2px 7px', borderRadius: 50,
            fontFamily: VB.font,
          }}>{label}</div>
        )}
      </div>
      <div style={{ padding: '10px 12px', flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 12, fontWeight: 700, color: VB.text, fontFamily: VB.fontHead, lineHeight: 1.3 }}>{title}</div>
          <div style={{ fontSize: 10, color: VB.textSub, marginTop: 2, display: 'flex', alignItems: 'center', gap: 2 }}>
            <svg width="9" height="9" viewBox="0 0 24 24" fill={VB.textSub}><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/></svg>
            {loc}
          </div>
        </div>
        <div>
          <div style={{ fontSize: 13, fontWeight: 800, color: VB.accent, fontFamily: VB.fontHead }}>{price}</div>
          <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
            {[
              ['M3 21h18M5 21V7l7-4 7 4v14M9 9h2M9 13h2M13 9h2M13 13h2', `${beds}`],
              ['M9 5H6a3 3 0 00-3 3v0a3 3 0 003 3h12a3 3 0 003-3v0a3 3 0 00-3-3h-3M3 11v3a4 4 0 004 4h10a4 4 0 004-4v-3', baths],
              [null, area],
            ].map(([d, val], i) => (
              <span key={i} style={{ fontSize: 9, color: VB.textSub, background: VB.surface2, padding: '2px 6px', borderRadius: 6, display: 'flex', alignItems: 'center', gap: 3 }}>
                {d && <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke={VB.textSub} strokeWidth="2" strokeLinecap="round"><path d={d}/></svg>}
                {val}
              </span>
            ))}
          </div>
        </div>
      </div>
      <div style={{ padding: 10, display: 'flex', alignItems: 'flex-start' }}>
        <div style={{
          width: 28, height: 28, borderRadius: 50, background: VB.accentSoft,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke={VB.accent} strokeWidth="2.5">
            <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
          </svg>
        </div>
      </div>
    </div>
  );
}

function VBBottomNav({ active = 0 }) {
  const items = [
    { d: 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', label: 'Home' },
    { d: 'M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16zM21 21l-4.35-4.35', label: 'Search' },
    { d: 'M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z', label: 'Messages' },
    { d: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2 M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0z', label: 'Profile' },
  ];
  return (
    <div style={{
      display: 'flex', borderTop: `1px solid ${VB.border}`,
      background: VB.surface, padding: '8px 0',
    }}>
      {items.map((item, i) => (
        <div key={i} style={{
          flex: 1, display: 'flex', flexDirection: 'column',
          alignItems: 'center', gap: 3,
        }}>
          <div style={{
            width: 36, height: 4, borderRadius: 2,
            background: i === active ? VB.grad : 'transparent',
            marginBottom: 2,
          }} />
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
            stroke={i === active ? VB.accent : VB.textMuted} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d={item.d} />
          </svg>
          <span style={{
            fontSize: 9, fontWeight: i === active ? 700 : 400,
            color: i === active ? VB.accent : VB.textMuted, fontFamily: VB.font,
          }}>{item.label}</span>
        </div>
      ))}
    </div>
  );
}

// ─── SCREENS ─────────────────────────────────────────────────────────────────

function VBScreenLanding() {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: VB.bg, fontFamily: VB.font }}>
      <div style={{
        flex: '0 0 58%', background: VB.grad,
        padding: '52px 24px 28px', display: 'flex', flexDirection: 'column',
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', top: -40, right: -40, width: 160, height: 160, borderRadius: '50%', background: 'rgba(255,255,255,0.07)' }} />
        <div style={{ position: 'absolute', bottom: -20, left: -20, width: 120, height: 120, borderRadius: '50%', background: 'rgba(255,255,255,0.05)' }} />
        <VBLogo onGradient size={17} />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', marginTop: 20 }}>
          <div style={{ fontSize: 28, fontWeight: 800, color: '#fff', lineHeight: 1.2, fontFamily: VB.fontHead, marginBottom: 12 }}>
            Find Rental Homes<br />Made Easy
          </div>
          <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.80)', lineHeight: 1.5, maxWidth: 240 }}>
            Discover your perfect home from thousands of verified rental listings.
          </div>
        </div>
        <div style={{ marginTop: 20 }}><VBSearchBar onGradient /></div>
      </div>
      <div style={{
        flex: 1, background: VB.surface,
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        marginTop: -20, padding: '28px 24px 16px',
        display: 'flex', flexDirection: 'column', gap: 12,
        boxShadow: '0 -4px 24px rgba(0,0,0,0.10)',
      }}>
        <button style={{
          width: '100%', padding: '14px', borderRadius: 16,
          background: VB.grad, border: 'none', color: '#fff',
          fontWeight: 700, fontSize: 15, fontFamily: VB.fontHead, boxShadow: VB.shadowCta,
        }}>Get Started</button>
        <button style={{
          width: '100%', padding: '14px', borderRadius: 16,
          background: 'transparent', border: `2px solid ${VB.accent}`,
          color: VB.accent, fontWeight: 700, fontSize: 15, fontFamily: VB.fontHead,
        }}>Create Account</button>
        <div style={{ textAlign: 'center', marginTop: 8 }}>
          <div style={{ fontSize: 10, color: VB.textMuted, letterSpacing: 1.5, fontWeight: 600, marginBottom: 14 }}>WHY CHOOSE US</div>
          <div style={{ display: 'flex', justifyContent: 'space-around' }}>
            {[
              ['M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16z M21 21l-4.35-4.35', 'Easy Search'],
              ['M22 11.08V12a10 10 0 1 1-5.93-9.14 M22 4L12 14.01l-3-3', 'Verified'],
              ['M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2z M7 11V7a5 5 0 0 1 10 0v4', 'Secure Pay'],
            ].map(([d, lbl], i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{
                  width: 44, height: 44, borderRadius: 14,
                  background: VB.accentSoft,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={VB.accent} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d}/></svg>
                </div>
                <span style={{ fontSize: 10, color: VB.textSub, fontWeight: 500 }}>{lbl}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function VBScreenLogin() {
  return (
    <div style={{ height: '100%', background: VB.grad, display: 'flex', flexDirection: 'column', position: 'relative', fontFamily: VB.font }}>
      <div style={{ position: 'absolute', top: -60, right: -60, width: 200, height: 200, borderRadius: '50%', background: 'rgba(255,255,255,0.07)' }} />
      <div style={{ padding: '52px 24px 0', flex: '0 0 auto' }}>
        <div style={{ marginBottom: 32 }}>
          <div style={{ width: 36, height: 36, borderRadius: 12, background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 28 }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
          </div>
          <VBLogo onGradient size={16} />
        </div>
        <div style={{ fontSize: 26, fontWeight: 800, color: '#fff', fontFamily: VB.fontHead, marginBottom: 4 }}>Welcome Back</div>
        <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.75)' }}>Sign in to continue</div>
      </div>
      {/* Var B: white card slides up */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
        <div style={{
          background: VB.surface, borderTopLeftRadius: 28, borderTopRightRadius: 28,
          padding: '28px 24px 24px', display: 'flex', flexDirection: 'column', gap: 14,
        }}>
          {[['EMAIL ADDRESS', 'Enter your email'], ['PASSWORD', 'Enter your password']].map(([label, hint], i) => (
            <div key={i}>
              <div style={{ fontSize: 11, color: VB.textSub, fontWeight: 600, marginBottom: 6, letterSpacing: 0.3 }}>{label}</div>
              <div style={{
                background: VB.surface2, borderRadius: 16,
                border: `1.5px solid ${VB.border}`,
                padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 10,
              }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={VB.textMuted} strokeWidth="2" strokeLinecap="round">
                  {i === 0
                    ? <><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></>
                    : <><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></>}
                </svg>
                <span style={{ fontSize: 12, color: VB.textMuted }}>{hint}</span>
              </div>
            </div>
          ))}
          <div style={{ textAlign: 'right' }}>
            <span style={{ fontSize: 11, color: VB.accent, fontWeight: 600 }}>Forgot Password?</span>
          </div>
          <button style={{
            padding: '14px', borderRadius: 16, background: VB.grad, border: 'none',
            color: '#fff', fontWeight: 700, fontSize: 15, fontFamily: VB.fontHead, boxShadow: VB.shadowCta,
          }}>Sign In</button>
          <button style={{
            padding: '13px', borderRadius: 16,
            background: VB.surface2, border: `1.5px solid ${VB.border}`,
            color: VB.text, fontWeight: 600, fontSize: 13, fontFamily: VB.font,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            <span style={{ fontWeight: 800, color: VB.accent }}>G</span> Continue with Google
          </button>
          <div style={{ textAlign: 'center' }}>
            <span style={{ fontSize: 12, color: VB.textSub }}>Don't have an account? </span>
            <span style={{ fontSize: 12, color: VB.accent, fontWeight: 700 }}>Sign Up</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function VBScreenHome() {
  const props = [
    { img: 'assets/property1.jpg', title: 'Modern Studio Loft', loc: 'Dasmariñas, Cavite', price: '₱8,500/mo', beds: 1, baths: '1', area: '32 m²', label: 'Popular' },
    { img: 'assets/property2.jpg', title: 'Cozy 2BR Apartment', loc: 'Bacoor, Cavite', price: '₱14,000/mo', beds: 2, baths: '1', area: '55 m²', label: 'New' },
    { img: 'assets/property3.jpg', title: 'Spacious Family Home', loc: 'Imus, Cavite', price: '₱22,000/mo', beds: 3, baths: '2', area: '90 m²', label: 'Featured' },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: VB.bg, fontFamily: VB.font }}>
      {/* Square-bottom gradient header */}
      <div style={{ background: VB.grad, padding: '44px 18px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
          <VBLogo onGradient size={15} />
          <div style={{ display: 'flex', gap: 12 }}>
            {[
              'M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z',
              'M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9 M13.73 21a2 2 0 0 1-3.46 0',
            ].map((d, i) => (
              <svg key={i} width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.9)" strokeWidth="2" strokeLinecap="round"><path d={d}/></svg>
            ))}
          </div>
        </div>
        <div style={{ fontSize: 17, fontWeight: 800, color: '#fff', fontFamily: VB.fontHead, marginBottom: 3 }}>Find Your Perfect Home</div>
        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.75)', marginBottom: 14 }}>Discover rental properties near you</div>
        <VBSearchBar onGradient />
      </div>
      <div style={{ padding: '14px 18px 8px', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['All', '1 Bedroom', '2 Bedrooms', '3+ Beds'].map((c, i) => (
          <VBChip key={i} label={c} active={i === 0} />
        ))}
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 18px 12px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ fontSize: 13, fontWeight: 700, color: VB.text, fontFamily: VB.fontHead }}>Featured in Dasmariñas</div>
        {props.map((p, i) => <VBPropertyCard key={i} {...p} />)}
      </div>
      <VBBottomNav active={0} />
    </div>
  );
}

function VBScreenSearch() {
  const results = [
    { img: 'assets/property3.jpg', title: 'Spacious Family Home', loc: 'Imus, Cavite', price: '₱22,000/mo', beds: 3, baths: '2', area: '90 m²', label: 'Featured' },
    { img: 'assets/property4.jpg', title: 'Bright Studio Unit', loc: 'Dasmariñas, Cavite', price: '₱7,500/mo', beds: 1, baths: '1', area: '28 m²', label: 'New' },
    { img: 'assets/property5.jpg', title: 'Modern 2BR Condo', loc: 'Bacoor, Cavite', price: '₱18,000/mo', beds: 2, baths: '2', area: '62 m²', label: 'Popular' },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: VB.bg, fontFamily: VB.font }}>
      {/* Var B: SURFACE header (not gradient) */}
      <div style={{ background: VB.surface, padding: '44px 18px 16px', borderBottom: `1px solid ${VB.border}` }}>
        <div style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 16, fontWeight: 800, color: VB.text, fontFamily: VB.fontHead, marginBottom: 4 }}>Search Properties</div>
          <div style={{ fontSize: 11, color: VB.textSub }}>Find your perfect rental home</div>
        </div>
        <VBSearchBar />
      </div>
      <div style={{ padding: '12px 18px 8px', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['All', 'Studio', '1 Bed', '2 Bed', '3+ Bed'].map((c, i) => (
          <VBChip key={i} label={c} active={i === 0} />
        ))}
      </div>
      <div style={{ padding: '0 18px 10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 12, fontWeight: 700, color: VB.text, fontFamily: VB.fontHead }}>24 Properties Found</span>
        <div style={{ display: 'flex', background: VB.surface2, borderRadius: 10, padding: 2, gap: 2 }}>
          {['List', 'Map'].map((v, i) => (
            <div key={i} style={{
              padding: '4px 12px', borderRadius: 8,
              background: i === 0 ? VB.accent : 'transparent',
              fontSize: 10, fontWeight: 600, color: i === 0 ? '#fff' : VB.textSub,
            }}>{v}</div>
          ))}
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 18px 12px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {results.map((p, i) => <VBPropertyCard key={i} {...p} />)}
      </div>
      <VBBottomNav active={1} />
    </div>
  );
}

function VBScreenDetail() {
  const amenities = ['WiFi', 'Air Conditioning', 'Parking', 'Pet Friendly', 'Balcony', 'Laundry'];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: VB.bg, fontFamily: VB.font }}>
      <div style={{ position: 'relative', height: 220, flexShrink: 0, background: '#ccc' }}>
        <img src="assets/property1.jpg" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.25) 0%, transparent 40%, rgba(0,0,0,0.5) 100%)' }} />
        <div style={{ position: 'absolute', top: 44, left: 16, width: 34, height: 34, borderRadius: 11, background: 'rgba(255,255,255,0.2)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
        </div>
        <div style={{ position: 'absolute', bottom: 12, left: 16 }}>
          <div style={{ background: VB.accent, color: '#fff', fontSize: 9, fontWeight: 700, padding: '3px 10px', borderRadius: 50, fontFamily: VB.font }}>Popular</div>
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 18px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 800, color: VB.text, fontFamily: VB.fontHead, lineHeight: 1.2 }}>Modern Studio Loft</div>
            <div style={{ fontSize: 11, color: VB.textSub, marginTop: 2 }}>Dasmariñas, Cavite</div>
          </div>
          <div style={{ fontSize: 18, fontWeight: 800, color: VB.accent, fontFamily: VB.fontHead }}>₱8,500<span style={{ fontSize: 11, fontWeight: 400, color: VB.textSub }}>/mo</span></div>
        </div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
          {[['M3 21h18M5 21V7l7-4 7 4v14', '1 Bed'], ['M9 5H6a3 3 0 00-3 3v0a3 3 0 003 3h12a3 3 0 003-3v0a3 3 0 00-3-3h-3', '1 Bath'], ['M3 3h18v18H3z M9 3v18 M3 9h18', '32 m²']].map(([d, val], i) => (
            <div key={i} style={{ flex: 1, background: VB.surface2, borderRadius: 12, padding: '10px 8px', textAlign: 'center' }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={VB.text} strokeWidth="2" strokeLinecap="round"><path d={d}/></svg>
              <div style={{ fontSize: 10, fontWeight: 600, color: VB.text, marginTop: 4 }}>{val}</div>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', borderBottom: `2px solid ${VB.border}`, marginBottom: 14 }}>
          {['Details', 'Amenities', 'Location'].map((tab, i) => (
            <div key={i} style={{
              flex: 1, textAlign: 'center', paddingBottom: 10,
              fontSize: 12, fontWeight: 700,
              color: i === 0 ? VB.accent : VB.textMuted,
              borderBottom: i === 0 ? `2px solid ${VB.accent}` : '2px solid transparent',
              marginBottom: -2, fontFamily: VB.fontHead,
            }}>{tab}</div>
          ))}
        </div>
        <div style={{ fontSize: 12, color: VB.textSub, lineHeight: 1.7 }}>
          A beautifully furnished studio loft in the heart of Dasmariñas. Features modern interiors, high ceilings, and complete appliances. Perfect for young professionals and students.
        </div>
        <div style={{ marginTop: 14, background: VB.surface, borderRadius: 16, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12, border: `1px solid ${VB.border}` }}>
          <div style={{ width: 42, height: 42, borderRadius: 50, background: VB.grad, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 700, fontSize: 16 }}>J</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, fontWeight: 700, color: VB.text }}>Juan dela Cruz</div>
            <div style={{ fontSize: 10, color: VB.textSub }}>Verified Landlord · 12 listings</div>
          </div>
          <div style={{ padding: '6px 12px', borderRadius: 50, background: VB.accentSoft, fontSize: 10, fontWeight: 700, color: VB.accent }}>Message</div>
        </div>
      </div>
      <div style={{ padding: '12px 18px', background: VB.surface, borderTop: `1px solid ${VB.border}`, display: 'flex', gap: 10 }}>
        <div style={{ flex: 1, padding: '13px', borderRadius: 16, border: `1.5px solid ${VB.accent}`, textAlign: 'center', color: VB.accent, fontFamily: VB.fontHead, fontWeight: 700, fontSize: 13 }}>360° Tour</div>
        <button style={{
          flex: 2, padding: '13px', borderRadius: 16,
          background: VB.grad, border: 'none', color: '#fff',
          fontWeight: 700, fontSize: 14, fontFamily: VB.fontHead, boxShadow: VB.shadowCta,
        }}>Apply Now</button>
      </div>
    </div>
  );
}

function VBScreenProfile() {
  const menu = [
    ['M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2 M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0z', 'Profile Information', 'Update your personal details'],
    ['M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z', 'My Rental', 'Active stay & next payment'],
    ['M9 11h6 M9 15h6 M5 7h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z M16 3v4 M8 3v4', 'My Applications', 'Track approvals & contracts'],
    ['M21 4H3a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2z M1 10h22', 'Payment Method', 'Manage payment option'],
    ['M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2z M7 11V7a5 5 0 0 1 10 0v4', 'Security', 'Change your password'],
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: VB.bg, fontFamily: VB.font }}>
      <div style={{ background: VB.grad, padding: '44px 18px 24px', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: -30, right: -30, width: 120, height: 120, borderRadius: '50%', background: 'rgba(255,255,255,0.07)' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 24 }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.9)" strokeWidth="2.5" strokeLinecap="round"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
          <span style={{ fontSize: 15, fontWeight: 700, color: '#fff', fontFamily: VB.fontHead }}>Profile</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ width: 72, height: 72, borderRadius: '50%', background: 'rgba(255,255,255,0.25)', border: '3px solid rgba(255,255,255,0.8)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="32" height="32" viewBox="0 0 24 24" fill="white"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
          </div>
          <div style={{ marginTop: 10, fontSize: 16, fontWeight: 800, color: '#fff', fontFamily: VB.fontHead }}>Juan dela Cruz</div>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.75)', marginTop: 2 }}>juan@email.com</div>
          <div style={{
            marginTop: 10, padding: '7px 24px', borderRadius: 50,
            background: 'rgba(255,255,255,0.2)', border: '1.5px solid rgba(255,255,255,0.5)',
            fontSize: 11, fontWeight: 700, color: '#fff',
          }}>Edit Profile</div>
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 18px' }}>
        <div style={{ background: VB.surface, borderRadius: 16, overflow: 'hidden', border: `1px solid ${VB.border}`, marginBottom: 12 }}>
          {menu.map(([d, label, sub], i) => (
            <React.Fragment key={i}>
              <div style={{ padding: '13px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 36, height: 36, borderRadius: 11, background: VB.accentSoft, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={VB.accent} strokeWidth="2" strokeLinecap="round"><path d={d}/></svg>
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12, fontWeight: 600, color: VB.text }}>{label}</div>
                  <div style={{ fontSize: 10, color: VB.textSub, marginTop: 1 }}>{sub}</div>
                </div>
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke={VB.textMuted} strokeWidth="2.5" strokeLinecap="round"><path d="M9 18l6-6-6-6"/></svg>
              </div>
              {i < menu.length - 1 && <div style={{ height: 1, background: VB.border, marginLeft: 62 }} />}
            </React.Fragment>
          ))}
        </div>
        <button style={{
          width: '100%', padding: '13px', borderRadius: 16,
          background: VB.grad, border: 'none', color: '#fff',
          fontWeight: 700, fontSize: 14, fontFamily: VB.fontHead, boxShadow: VB.shadowCta,
        }}>Logout</button>
      </div>
      <VBBottomNav active={3} />
    </div>
  );
}

window.VB = VB;
window.VBLogo = VBLogo;
window.VBSearchBar = VBSearchBar;
window.VBChip = VBChip;
window.VBPropertyCard = VBPropertyCard;
window.VBBottomNav = VBBottomNav;
window.VBScreenLanding = VBScreenLanding;
window.VBScreenLogin = VBScreenLogin;
window.VBScreenHome = VBScreenHome;
window.VBScreenSearch = VBScreenSearch;
window.VBScreenDetail = VBScreenDetail;
window.VBScreenProfile = VBScreenProfile;
