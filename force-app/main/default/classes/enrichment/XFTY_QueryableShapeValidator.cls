/**
 * Rejects an `XFTY_InjectConfig` the enrichment pass cannot honour:
 *
 * - **Capability limits** (always enforced): child injection is one level deep -
 *   `childDepth(n > 1)` and a multi-hop `injectChild` path are not supported,
 *   because a SOQL subquery cannot nest and the pass does not walk further.
 * - **SOQL-shape limits** (`breakSoqlLimits()` turns these off): a parent climb
 *   past the platform's relationship-hop limit. An injected shape the platform
 *   could never produce is a landmine in an integration test.
 */
@IsTest
public class XFTY_QueryableShapeValidator {

    public static void validate(XFTY_InjectConfig config) {
        rejectUnsupportedChildDepth(config);
        for (List<SObjectField> path : config.includedChildPaths) {
            rejectMultiHopChild(path);
        }
        if (config.soqlLimitsLifted) {
            return;
        }
        rejectOverDeep('parentDepth', config.parentDepthLimit, XFTY_InjectConfig.SOQL_PARENT_HOPS);
        for (List<SObjectField> path : config.includedParentPaths) {
            rejectOverLong('an injectParent path', path.size(), XFTY_InjectConfig.SOQL_PARENT_HOPS);
        }
    }

    private static void rejectUnsupportedChildDepth(XFTY_InjectConfig config) {
        if (config.childDepthLimit == null || config.childDepthLimit <= XFTY_InjectConfig.SOQL_CHILD_DEPTH) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'inject: childDepth ' + config.childDepthLimit + ' is not supported - child injection is one level '
                        + '(a SOQL subquery cannot nest). Enrich the child collection separately with inject(childField, ...).'
        );
    }

    private static void rejectMultiHopChild(List<SObjectField> path) {
        if (path.size() == 1) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'inject: injectChild takes a single child-lookup field. A path ' + path + ' would need a nested '
                        + 'subquery, which is not supported - enrich that collection separately.'
        );
    }

    private static void rejectOverDeep(String name, Integer value, Integer soqlMax) {
        if (value == null || value <= soqlMax) {
            return;
        }
        throw overSoql(name + ' ' + value + ' exceeds the ' + soqlMax + ' a single SOQL query allows');
    }

    private static void rejectOverLong(String label, Integer hops, Integer soqlMax) {
        if (hops <= soqlMax) {
            return;
        }
        throw overSoql(label + ' is ' + hops + ' hops, past the ' + soqlMax + ' a single SOQL query allows');
    }

    private static XFTY_DummySObjectFtyProviderException overSoql(String detail) {
        return new XFTY_DummySObjectFtyProviderException(
                'inject: ' + detail + '. Call breakSoqlLimits() on the config to allow it.'
        );
    }
}
