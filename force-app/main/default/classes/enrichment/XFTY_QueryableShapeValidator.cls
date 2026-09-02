/**
 * Rejects an `XFTY_InjectConfig` that describes a shape no single SOQL query
 * could return - a parent climb past the platform's relationship-hop limit, a
 * child subquery nested deeper than one level. An injected shape the platform
 * could never produce is a landmine in an integration test.
 *
 * `config.breakSoqlLimits()` turns the check off; past that point the developer
 * owns what they asked for.
 */
@IsTest
public class XFTY_QueryableShapeValidator {

    public static void validate(XFTY_InjectConfig config) {
        if (config.soqlLimitsLifted) {
            return;
        }
        rejectDepth('parentDepth', config.parentDepthLimit, XFTY_InjectConfig.SOQL_PARENT_HOPS);
        rejectDepth('childDepth', config.childDepthLimit, XFTY_InjectConfig.SOQL_CHILD_DEPTH);
        for (List<SObjectField> path : config.includedParentPaths) {
            rejectLength('an injectParent path', path.size(), XFTY_InjectConfig.SOQL_PARENT_HOPS);
        }
        for (List<SObjectField> path : config.includedChildPaths) {
            rejectLength('an injectChild path', path.size() - 1, XFTY_InjectConfig.SOQL_PARENT_HOPS);
        }
    }

    private static void rejectDepth(String name, Integer value, Integer soqlMax) {
        if (value == null || value <= soqlMax) {
            return;
        }
        throw offending(name + ' ' + value + ' exceeds the ' + soqlMax + ' a single SOQL query allows');
    }

    private static void rejectLength(String label, Integer hops, Integer soqlMax) {
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
