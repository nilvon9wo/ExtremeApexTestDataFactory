/**
 * Applies each `includeOptional(...)` path by promoting its head relationship from
 * optional to required, on a copy of the master template.
 */
@IsTest
public class XFTY_ForcedRelationships {

    public static XFTY_DummySObjectMasterTemplate apply(
            List<List<SObjectField>> paths,
            XFTY_DummySObjectMasterTemplate template
    ) {
        if (paths.isEmpty()) {
            return template;
        }
        XFTY_DummySObjectMasterTemplate forced = template.copy();
        for (List<SObjectField> path : paths) {
            promoteHead(path, forced, template);
        }
        return forced;
    }

    private static void promoteHead(
            List<SObjectField> path,
            XFTY_DummySObjectMasterTemplate forced,
            XFTY_DummySObjectMasterTemplate source
    ) {
        SObjectField head = path[0];
        XFTY_DummyDefaultRelationshipIntf optional = source.optionalRelationshipBySObjectFieldMap.get(head);
        if (optional == null) {
            assertIsRelationship(source, head);
            return;
        }
        forced.remove(head);
        forced.putRequired(head, optional);
    }

    private static void assertIsRelationship(XFTY_DummySObjectMasterTemplate template, SObjectField head) {
        Boolean isRelationship = template.requiredRelationshipBySObjectFieldMap.containsKey(head);
        if (isRelationship) {
            return;
        }
        String message = 'includeOptional: ' + head + ' is not a relationship on the Provider for '
                + template.primaryTargetField + '.';
        throw new XFTY_DummySObjectFtyProviderException(message);
    }
}
