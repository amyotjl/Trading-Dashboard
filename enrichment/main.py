import logging
import requests
import yfinance as yf
from fastapi import FastAPI, HTTPException

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="Ticker Enrichment Service")


def _fetch_info(symbol: str) -> dict:
    try:
        info = yf.Ticker(symbol).info
        # yfinance returns {"trailingPegRatio": None} when ticker is unknown
        return info if info.get("quoteType") else {}
    except Exception as e:
        logger.warning("yfinance error for %s: %s", symbol, e)
        return {}


def _format(symbol: str, info: dict) -> dict:
    return {
        "symbol":      symbol,
        "name":        info.get("longName") or info.get("shortName"),
        "sector":      info.get("sector"),
        "home_page":   info.get("website"),
        "description": info.get("longBusinessSummary"),
        "exchange":    info.get("exchange"),
        "currency":    info.get("currency"),
        "country":     info.get("country"),
    }


YAHOO_SEARCH_URL = "https://query1.finance.yahoo.com/v1/finance/search"
CANADIAN_SUFFIXES = (".TO", ".V", ".CN", ".NE", ".VN")


@app.get("/search")
def search_ticker(q: str):
    """
    Search Yahoo Finance for a ticker by company name.
    Prefers Canadian exchange symbols (.TO, .V, .CN, .NE, .VN).
    Returns {"symbol": "...", "name": "..."} or 404.
    """
    logger.info("Ticker search: %s", q)
    try:
        resp = requests.get(
            YAHOO_SEARCH_URL,
            params={"q": q, "quotesCount": 5, "newsCount": 0, "listsCount": 0},
            timeout=8,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        resp.raise_for_status()
    except requests.RequestException as e:
        logger.warning("Yahoo search failed for %s: %s", q, e)
        raise HTTPException(status_code=502, detail="Yahoo Finance search failed")

    quotes = resp.json().get("quotes", [])
    canadian = [qt for qt in quotes if any(qt.get("symbol", "").endswith(s) for s in CANADIAN_SUFFIXES)]
    ranked = canadian + [qt for qt in quotes if qt not in canadian]

    for quote in ranked:
        symbol = quote.get("symbol", "")
        if symbol:
            return {"symbol": symbol, "name": quote.get("shortname", "")}

    raise HTTPException(status_code=404, detail=f"No ticker found for: {q}")


@app.get("/enrich/{ticker:path}")
def enrich(ticker: str):
    """
    Fetch Yahoo Finance metadata for a ticker.

    Handles Canadian SEDI tickers:
    - "IGM.TO"  → tried directly (.TO = Toronto)
    - "ENB"     → tried as-is first; if sector is missing, also tried as ENB.TO
    - "36E.F"   → tried directly (.F = Frankfurt)
    """
    logger.info("Enriching ticker: %s", ticker)

    info = _fetch_info(ticker)

    # For plain tickers with no exchange suffix, fall back to TSX (.TO)
    if not info.get("sector") and "." not in ticker:
        tsx = f"{ticker}.TO"
        logger.info("No sector for %s — retrying as %s", ticker, tsx)
        tsx_info = _fetch_info(tsx)
        if tsx_info.get("sector"):
            info = tsx_info
            ticker = tsx

    if not info:
        raise HTTPException(status_code=404, detail=f"No data found for {ticker}")

    result = _format(ticker, info)
    logger.info("Result for %s: sector=%s home_page=%s", ticker, result["sector"], result["home_page"])
    return result


def _fetch_history(symbol: str, period: str):
    try:
        t = yf.Ticker(symbol)
        hist = t.history(period=period)
        return hist if not hist.empty else None
    except Exception as e:
        logger.warning("yfinance history error for %s: %s", symbol, e)
        return None


@app.get("/ohlcv/{ticker:path}")
def ohlcv(ticker: str, period: str = "2y"):
    logger.info("OHLCV request for: %s (period=%s)", ticker, period)

    hist = _fetch_history(ticker, period)

    if hist is None and "." not in ticker:
        tsx = f"{ticker}.TO"
        logger.info("No OHLCV for %s — retrying as %s", ticker, tsx)
        hist = _fetch_history(tsx, period)
        if hist is not None:
            ticker = tsx

    if hist is None:
        raise HTTPException(status_code=404, detail=f"No OHLCV data for {ticker}")

    data = [
        {
            "time":  date.strftime("%Y-%m-%d"),
            "open":  round(float(row["Open"]),  4),
            "high":  round(float(row["High"]),  4),
            "low":   round(float(row["Low"]),   4),
            "close": round(float(row["Close"]), 4),
        }
        for date, row in hist.iterrows()
    ]
    return {"ticker": ticker, "data": data}


# ── Market data ───────────────────────────────────────────────────────────────

INDEX_SYMBOLS = [
    ("^GSPTSE",  "TSX Composite"),
    ("XIU.TO",   "TSX 60"),
    ("^GSPC",    "S&P 500"),
    ("USDCAD=X", "USD/CAD"),
    ("CL=F",     "Crude Oil"),
    ("GC=F",     "Gold"),
]

SECTOR_ETFS = [
    ("Financials",       "XFN.TO",  33),
    ("Energy",           "XEG.TO",  18),
    ("Materials",        "XBM.TO",  13),
    ("Industrials",      "ZIN.TO",   9),
    ("Technology",       "XIT.TO",   7),
    ("Communication",    "BCE.TO",   5),
    ("Utilities",        "XUT.TO",   4),
    ("Consumer Staples", "XST.TO",   4),
    ("Real Estate",      "XRE.TO",   3),
    ("Health Care",      "XHC.TO",   2),
]

TSX_UNIVERSE = [
    "RY.TO", "TD.TO", "BNS.TO", "BMO.TO", "ENB.TO", "CNQ.TO", "TRP.TO", "SU.TO",
    "ABX.TO", "ATD.TO", "CNR.TO", "CP.TO", "BCE.TO", "MFC.TO", "SLF.TO", "WPM.TO",
    "AEM.TO", "FFH.TO", "T.TO", "SHOP.TO", "BAM.TO", "BN.TO", "IFC.TO",
    "POW.TO", "EMA.TO", "FTS.TO", "CCO.TO", "NTR.TO", "TOU.TO", "CVE.TO",
    "K.TO", "AGI.TO", "FM.TO", "GFL.TO", "WN.TO", "L.TO", "MRU.TO",
]


def _pct(new_val: float, old_val: float) -> float:
    if old_val and old_val != 0:
        return round((new_val - old_val) / abs(old_val) * 100, 2)
    return 0.0


@app.get("/market/indices")
def market_indices():
    symbols = [s for s, _ in INDEX_SYMBOLS]
    sym_to_name = {s: n for s, n in INDEX_SYMBOLS}
    try:
        data = yf.download(symbols, period="1mo", interval="1d", auto_adjust=True, progress=False)
    except Exception as e:
        logger.warning("market/indices download error: %s", e)
        raise HTTPException(status_code=503, detail="Market data unavailable")

    close = data["Close"]
    result = []
    for sym in symbols:
        try:
            series = close[sym].dropna()
            if len(series) < 2:
                continue
            last = float(series.iloc[-1])
            prev = float(series.iloc[-2])
            spark = [round(float(v), 4) for v in series.iloc[-20:]]
            result.append({
                "symbol":     sym,
                "name":       sym_to_name[sym],
                "last":       round(last, 4),
                "prev":       round(prev, 4),
                "change_pct": _pct(last, prev),
                "spark":      spark,
            })
        except Exception as e:
            logger.warning("index %s failed: %s", sym, e)

    return result


@app.get("/market/sectors")
def market_sectors():
    symbols = [sym for _, sym, _ in SECTOR_ETFS]
    try:
        data = yf.download(symbols, period="ytd", interval="1d", auto_adjust=True, progress=False)
    except Exception as e:
        logger.warning("market/sectors download error: %s", e)
        raise HTTPException(status_code=503, detail="Market data unavailable")

    close = data["Close"]
    result = []
    for name, sym, weight in SECTOR_ETFS:
        try:
            series = close[sym].dropna()
            if len(series) < 2:
                continue
            last = float(series.iloc[-1])
            result.append({
                "name":   name,
                "weight": weight,
                "day":    _pct(last, float(series.iloc[-2])),
                "week":   _pct(last, float(series.iloc[max(0, len(series) - 6)])),
                "month":  _pct(last, float(series.iloc[max(0, len(series) - 22)])),
                "ytd":    _pct(last, float(series.iloc[0])),
            })
        except Exception as e:
            logger.warning("sector %s (%s) failed: %s", name, sym, e)

    return result


@app.get("/market/movers")
def market_movers(type: str = "gainers"):
    try:
        data = yf.download(TSX_UNIVERSE, period="5d", interval="1d", auto_adjust=True, progress=False)
    except Exception as e:
        logger.warning("market/movers download error: %s", e)
        raise HTTPException(status_code=503, detail="Market data unavailable")

    close = data["Close"]
    volume = data["Volume"]
    rows = []
    for sym in TSX_UNIVERSE:
        try:
            cs = close[sym].dropna()
            if len(cs) < 2:
                continue
            last = float(cs.iloc[-1])
            prev = float(cs.iloc[-2])
            vs = volume[sym].dropna()
            vol = int(vs.iloc[-1]) if len(vs) > 0 else 0
            ticker = sym.replace(".TO", "")
            rows.append({"ticker": ticker, "name": ticker, "last": round(last, 2), "chg": _pct(last, prev), "vol": vol})
        except Exception as e:
            logger.warning("mover %s failed: %s", sym, e)

    if type == "losers":
        rows.sort(key=lambda r: r["chg"])
    elif type == "active":
        rows.sort(key=lambda r: r["vol"] * r["last"], reverse=True)
    else:
        rows.sort(key=lambda r: r["chg"], reverse=True)

    return rows[:15]


@app.get("/health")
def health():
    return {"status": "ok"}
