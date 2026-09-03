/**
 * Answers "does this config want the ancestor / child / inverse at this position?"
 * for `XFTY_BundleEnricher`'s recursive walk. Built once from the config; paths
 * are compared as `XFTY_PathKey` strings.
 */
@IsTest
public class XFTY_EnrichmentSelection {

    private final XFTY_InjectConfig config;
    private final Set<String> includedParentKeys = new Set<String>();
    private final Set<String> excludedParentKeys = new Set<String>();

    public XFTY_EnrichmentSelection(XFTY_InjectConfig config) {
        this.config = config;
        for (List<SObjectField> path : config.includedParentPaths) {
            this.includeWithPrefixes(path);
        }
        for (XFTY_InjectConfig.AncestorValue ancestorValue : config.ancestorValues) {
            this.includeWithPrefixes(ancestorValue.relationshipPrefix());
        }
        for (List<SObjectField> path : config.excludedParentPaths) {
            this.excludedParentKeys.add(XFTY_PathKey.of(path));
        }
    }

    /**
     * `pathFromEntry` is the upward-hop path from the entry target to this
     * candidate ancestor - `null` once the walk has turned downward, so
     * `injectParent` never reaches into a child's ancestors.
     */
    public Boolean wantsAncestor(List<SObjectField> pathFromEntry) {
        if (pathFromEntry == null) {
            return this.config.fromAllParents;
        }
        if (this.hasExcludedPrefix(pathFromEntry)) {
            return false;
        }
        return this.config.fromAllParents || this.includedParentKeys.contains(XFTY_PathKey.of(pathFromEntry));
    }

    /** Whether an ancestor generated for the level below should carry that level back as its child subquery. */
    public Boolean wantsInverse(SObjectField relationshipField) {
        return this.config.fromAllChildren && !this.config.excludedChildFields.contains(relationshipField);
    }

    /**
     * The child relationship fields to inject at this position. `childPathHere` is
     * the child-hop path already walked from the entry target (empty at the root),
     * so `injectChild(field)` is picked up at the root and an `injectChildValue`
     * path contributes its next hop wherever the walk has reached its prefix.
     */
    public Set<SObjectField> childFieldsOn(XFTY_DummySObjectBundle subBundle, List<SObjectField> childPathHere) {
        Set<SObjectField> present = materialised(subBundle.childRelationshipFields());
        Set<SObjectField> wanted = new Set<SObjectField>();
        if (this.config.fromAllChildren) {
            wanted.addAll(present);
        }
        wanted.addAll(this.namedNextHopsFollowing(childPathHere, present));
        wanted.removeAll(this.config.excludedChildFields);
        return wanted;
    }

    private Set<SObjectField> namedNextHopsFollowing(List<SObjectField> childPathHere, Set<SObjectField> present) {
        Set<SObjectField> named = new Set<SObjectField>();
        if (childPathHere.isEmpty()) {
            for (SObjectField childField : this.config.includedChildFields) {
                if (present.contains(childField)) {
                    named.add(childField);
                }
            }
        }
        for (XFTY_InjectConfig.ChildValue childValue : this.config.childValues) {
            SObjectField nextHop = nextHopAfter(childPathHere, childValue.relationshipPrefix());
            if (nextHop != null && present.contains(nextHop)) {
                named.add(nextHop);
            }
        }
        return named;
    }

    private static SObjectField nextHopAfter(List<SObjectField> walked, List<SObjectField> fullPath) {
        if (fullPath.size() <= walked.size()) {
            return null;
        }
        for (Integer i = 0; i < walked.size(); i++) {
            if (fullPath[i] != walked[i]) {
                return null;
            }
        }
        return fullPath[walked.size()];
    }

    private void includeWithPrefixes(List<SObjectField> path) {
        for (Integer length = 1; length <= path.size(); length++) {
            this.includedParentKeys.add(XFTY_PathKey.of(prefixOf(path, length)));
        }
    }

    private Boolean hasExcludedPrefix(List<SObjectField> path) {
        for (Integer length = 1; length <= path.size(); length++) {
            if (this.excludedParentKeys.contains(XFTY_PathKey.of(prefixOf(path, length)))) {
                return true;
            }
        }
        return false;
    }

    private static List<SObjectField> prefixOf(List<SObjectField> path, Integer length) {
        List<SObjectField> prefix = new List<SObjectField>();
        for (Integer i = 0; i < length; i++) {
            prefix.add(path[i]);
        }
        return prefix;
    }

    private static Set<SObjectField> materialised(Set<SObjectField> keySet) {
        Set<SObjectField> real = new Set<SObjectField>();
        real.addAll(keySet);
        return real;
    }
}
