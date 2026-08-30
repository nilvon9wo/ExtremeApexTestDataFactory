/**
 * Turns the `Set` of matching keys from `XFTY_DummySObjectProviderLookupIntf.keysFor(...)`
 * into the single key to generate a parent from: the most specific match, or the
 * plain type key when nothing refined matched. Ambiguity (two equally specific
 * matches) is an error - the caller must supply an explicit key.
 */
@IsTest
public class XFTY_LookupKeys {

    public static XFTY_LookupKeyIntf resolve(XFTY_DummySObjectProviderLookupIntf providerLookup, SObject sObj) {
        Set<XFTY_LookupKeyIntf> matches = providerLookup.keysFor(sObj);
        if (matches.isEmpty()) {
            return XFTY_LookupKey.get(sObj.getSObjectType());
        }

        XFTY_LookupKeyIntf best = null;
        List<String> topTierHashes = new List<String>();
        for (XFTY_LookupKeyIntf candidate : matches) {
            if (best == null || candidate.getSpecificity() > best.getSpecificity()) {
                best = candidate;
                topTierHashes = new List<String>{ candidate.getHashKey() };
            } else if (candidate.getSpecificity() == best.getSpecificity()
                    && candidate.getHashKey() != best.getHashKey()) {
                topTierHashes.add(candidate.getHashKey());
            }
        }

        if (topTierHashes.size() > 1) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'Ambiguous Provider variant for ' + sObj.getSObjectType()
                            + ': ' + topTierHashes + '. Supply an explicit lookup key.'
            );
        }
        return best;
    }
}
