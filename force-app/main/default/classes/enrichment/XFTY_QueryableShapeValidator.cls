/**
 * Rejects an `XFTY_InjectConfig` that describes a shape no single SOQL query
 * could return - a parent climb past the platform's relationship-hop limit, or a
 * child subquery nested deeper than one level. An injected shape the platform
 * could never produce is a landmine in an integration test.
 *
 * `config.breakSoqlLimits()` turns those checks off; past that point the
 * developer owns what they asked for. The one check it does *not* lift is that
 * `childDepth` reaches as deep as every `injectChildValue` path - that is an
 * internal consistency error, not a SOQL-shape one.
 */
@IsTest
public class XFTY_QueryableShapeValidator {

    public static void validate(XFTY_InjectConfig config) {
        rejectChildValuesDeeperThanChildDepth(config);
        if (config.soqlLimitsLifted) {
            return;
        }
        rejectOverSoql('parentDepth ' + config.parentDepthLimit, config.parentDepthLimit, XFTY_InjectConfig.SOQL_PARENT_HOPS);
        rejectOverSoql('childDepth ' + config.childDepthLimit, config.childDepthLimit, XFTY_InjectConfig.SOQL_CHILD_DEPTH);
        for (List<SObjectField> path : config.includedParentPaths) {
            rejectOverSoql('an injectParent path of ' + path.size() + ' hops', path.size(), XFTY_InjectConfig.SOQL_PARENT_HOPS);
        }
    }

    /**
     * An `injectChildValue` path can only place its value if the walk descends
     * far enough - `childDepth` has to allow as many child levels as the path has.
     */
    private static void rejectChildValuesDeeperThanChildDepth(XFTY_InjectConfig config) {
        for (XFTY_InjectConfig.ChildValue childValue : config.childValues) {
            Integer childLevels = childValue.relationshipPrefix().size();
            if (childLevels > config.childDepthLimit) {
                throw new XFTY_DummySObjectFtyProviderException(
                        'inject: an injectChildValue path reaches ' + childLevels + ' child level(s) but childDepth is '
                                + config.childDepthLimit + '. Raise childDepth (past ' + XFTY_InjectConfig.SOQL_CHILD_DEPTH
                                + ' also needs breakSoqlLimits()).'
                );
            }
        }
    }

    private static void rejectOverSoql(String label, Integer value, Integer soqlMax) {
        if (value == null || value <= soqlMax) {
            return;
        }
        throw new XFTY_DummySObjectFtyProviderException(
                'inject: ' + label + ' exceeds the ' + soqlMax + ' a single SOQL query allows. '
                        + 'Call breakSoqlLimits() on the config to allow it.'
        );
    }
}
