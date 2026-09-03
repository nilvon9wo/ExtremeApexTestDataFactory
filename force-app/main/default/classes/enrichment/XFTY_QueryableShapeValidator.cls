/**
 * Rejects an `XFTY_InjectConfig` that describes a shape no single SOQL query
 * could return - a parent climb past the platform's relationship-hop limit, or a
 * child subquery nested deeper than one level. An injected shape the platform
 * could never produce is a landmine in an integration test.
 *
 * `config.breakSoqlLimits()` turns every check here off; past that point the
 * developer owns what they asked for.
 */
@IsTest
public class XFTY_QueryableShapeValidator {

    public static void validate(XFTY_InjectConfig config) {
        if (config.soqlLimitsLifted) {
            return;
        }
        rejectOverDeep('parentDepth', config.parentDepthLimit, XFTY_InjectConfig.SOQL_PARENT_HOPS);
        rejectOverDeep('childDepth', config.childDepthLimit, XFTY_InjectConfig.SOQL_CHILD_DEPTH);
        for (List<SObjectField> path : config.includedParentPaths) {
            rejectOverLong('an injectParent path', path.size(), XFTY_InjectConfig.SOQL_PARENT_HOPS);
        }
    }

    private static void rejectOverDeep(String name, Integer value, Integer soqlMax) {
        if (value == null || value <= soqlMax) {
            return;
        }
        throw offending(name + ' ' + value + ' exceeds the ' + soqlMax + ' a single SOQL query allows');
    }

    private static void rejectOverLong(String label, Integer hops, Integer soqlMax) {
        if (hops <= soqlMax) {
            return;
        }
        throw offending(label + ' is ' + hops + ' hops, past the ' + soqlMax + ' a single SOQL query allows');
    }

    private static XFTY_DummySObjectFtyProviderException offending(String detail) {
        return new XFTY_DummySObjectFtyProviderException(
                'inject: ' + detail + '. Call breakSoqlLimits() on the config to allow it.'
        );
    }
}
