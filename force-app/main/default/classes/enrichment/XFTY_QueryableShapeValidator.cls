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
        rejectOverSoql('parentDepth ' + config.parentDepthLimit, config.parentDepthLimit, XFTY_InjectConfig.SOQL_PARENT_HOPS);
        rejectOverSoql('childDepth ' + config.childDepthLimit, config.childDepthLimit, XFTY_InjectConfig.SOQL_CHILD_DEPTH);
        for (List<SObjectField> path : config.includedParentPaths) {
            rejectOverSoql('an injectParent path of ' + path.size() + ' hops', path.size(), XFTY_InjectConfig.SOQL_PARENT_HOPS);
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
