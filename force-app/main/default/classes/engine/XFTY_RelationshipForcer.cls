/**
 * Applies each `includeOptional(...)` path by promoting its head relationship from
 * optional to required, on a copy of the master template.
 */
@IsTest
public class XFTY_RelationshipForcer {

    public static XFTY_DummySObjectMasterTemplate apply(
            List<List<SObjectField>> paths,
            XFTY_DummySObjectMasterTemplate template
    ) {
        if (paths.isEmpty()) {
            return template;
        }
        XFTY_DummySObjectMasterTemplate forced = template.copy();
        for (List<SObjectField> path : paths) {
            SObjectField head = path[0];
            promoteHead(head, forced, template);
        }
        return forced;
    }

    private static void promoteHead(
            SObjectField head,
            XFTY_DummySObjectMasterTemplate forced,
            XFTY_DummySObjectMasterTemplate source
    ) {
        XFTY_DummyDefaultRelationshipIntf optional = source.optionalRelationshipBySObjectFieldMap.get(head);
        if (optional == null) {
            assertIsRelationship(source, head);
            return;
        }
        forced.remove(head);
        forced.putRequired(head, optional);
    }

    private static void assertIsRelationship(XFTY_DummySObjectMasterTemplate template, SObjectField head) {
        if (template.requiredRelationshipBySObjectFieldMap.containsKey(head)) {
            return;
        }
        String message =
                'includeOptional: ' + head + ' is not a relationship on the Provider for ' + template.primaryTargetField + '.';
        throw new XFTY_DummySObjectFtyProviderException(message);
    }
}
