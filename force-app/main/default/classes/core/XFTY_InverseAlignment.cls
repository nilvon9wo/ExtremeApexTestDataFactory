/**
 * The inverse of the 1:1 parent alignment: for each parent record, the child
 * records whose foreign key points at it. Matched on the Id when the parents
 * carry one, otherwise position for position (the `NEVER` / pre-`flush` case).
 * Behind `XFTY_DummySObjectBundle.primariesResolvingTo` and used by
 * `XFTY_BundleEnricher` to graft an ancestor's inverse child subquery.
 */
@IsTest
public class XFTY_InverseAlignment {

    private static final String ID_FIELD = 'Id';

    public static List<List<SObject>> childrenPerParent(
            List<SObject> parents,
            List<SObject> children,
            SObjectField relationshipField
    ) {
        List<List<SObject>> perParent = new List<List<SObject>>();
        for (Integer parentRow = 0; parentRow < parents.size(); parentRow++) {
            Object parentId = idOf(parents[parentRow]);
            List<SObject> matches = (parentId == null)
                    ? positionMatch(children, parentRow)
                    : foreignKeyMatch(children, relationshipField, parentId);
            perParent.add(matches);
        }
        return perParent;
    }

    private static Object idOf(SObject record) {
        return (record == null)
                ? null
                : record.get(ID_FIELD);
    }

    private static List<SObject> foreignKeyMatch(List<SObject> children, SObjectField relationshipField, Object parentId) {
        List<SObject> matches = new List<SObject>();
        for (SObject child : children) {
            if (child != null && child.get(relationshipField) == parentId) {
                matches.add(child);
            }
        }
        return matches;
    }

    private static List<SObject> positionMatch(List<SObject> children, Integer parentRow) {
        return (parentRow < children.size())
                ? new List<SObject>{ children[parentRow] }
                : new List<SObject>();
    }
}
