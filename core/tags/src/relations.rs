use crate::tags::Tags;

pub struct RelationNode<T> {
    tags: Tags,
    members: Vec<Member<T>>,
}

impl<T: Default> Default for RelationNode<T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T> RelationNode<T> {
    pub fn new() -> Self {
        Self {
            tags: Tags::new(),
            members: Vec::new(),
        }
    }

    pub fn with_tags(tags: Tags) -> Self {
        Self {
            tags,
            members: Vec::new(),
        }
    }

    pub fn add_member(&mut self, role: Option<String>, node: T) {
        self.members.push(Member::new(role, node));
    }

    pub fn add_member_with_role<S: Into<String>>(&mut self, role: S, node: T) {
        self.members.push(Member::new(Some(role.into()), node));
    }

    pub fn tags(&self) -> &Tags {
        &self.tags
    }

    pub fn members(&self) -> &[Member<T>] {
        &self.members
    }
}

pub struct Member<T> {
    role: Option<String>,
    node: T,
}

impl<T> Member<T> {
    pub fn new<S: Into<String>>(role: Option<S>, node: T) -> Self {
        let role = role.map(|r| r.into());
        Self { role, node }
    }

    pub fn role(&self) -> Option<&str> {
        self.role.as_deref()
    }

    pub fn node(&self) -> &T {
        &self.node
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_relation_node_is_empty() {
        let rel: RelationNode<u64> = RelationNode::new();
        assert_eq!(rel.tags().len(), 0);
        assert_eq!(rel.members().len(), 0);
    }

    #[test]
    fn test_add_member_preserves_order() {
        let mut rel = RelationNode::new();
        rel.add_member_with_role("outer", 1);
        rel.add_member_with_role("inner", 2);

        assert_eq!(rel.members().len(), 2);
        assert_eq!(rel.members()[0].role(), Some("outer"));
        assert_eq!(*rel.members()[0].node(), 1);
        assert_eq!(rel.members()[1].role(), Some("inner"));
        assert_eq!(*rel.members()[1].node(), 2);
    }
}
