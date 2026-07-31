- (CGPoint)centerOfRegion:(VNFaceLandmarkRegion2D *)region inRect:(CGRect)rect {
    if (!region || region.pointCount == 0) return CGPointZero;
    CGFloat x = 0, y = 0;
    for (NSUInteger i = 0; i < region.pointCount; i++) {
        CGPoint p = region.normalizedPoints[i];
        x += p.x;
        y += p.y;
    }
    x /= region.pointCount;
    y /= region.pointCount;
    return CGPointMake(rect.origin.x + x * rect.size.width, rect.origin.y + y * rect.size.height);
}
